#include <Arduino_LSM9DS1.h>
#include "arduinoFFT.h"

#include "model.h"
#include <TensorFlowLite.h>
#include "tensorflow/lite/micro/all_ops_resolver.h"
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_log.h"
#include "tensorflow/lite/micro/system_setup.h"
#include "tensorflow/lite/schema/schema_generated.h"


// Globals, used for compatibility with Arduino-style sketches.
namespace {
const tflite::Model* my_model = nullptr;
tflite::MicroInterpreter* interpreter = nullptr;
TfLiteTensor* input = nullptr;
TfLiteTensor* output = nullptr;

constexpr int kTensorArenaSize = 100 * 1024;
// Keep aligned to 16 bytes for CMSIS
alignas(16) uint8_t tensor_arena[kTensorArenaSize];
}  // namespace

extern unsigned char mlp_model[];

#define	DATA_Q_SIZE 300
#define SAMPLE_RATE 50
#define FI_DURATION 1
#define SP_THRESHOLD 5.729578 

#define BIO_FEEDBACK_PIN 3
#define RED 22     
#define BLUE 24     
#define GREEN 23

#define FI_MEAN 0.28437225113276526
#define FI_IQR 32.850691970963264
#define SP_MEAN 40.700684
#define SP_IQR 104.30908200
#define VAR_MEAN 4435.324558288575
#define VAR_IQR 12188.92268173838

long START_TIME = 0;
int SAMPLE_INTERVAL_MS = (1000/SAMPLE_RATE);

float ax, ay, az;
float gx, gy, gz;
long pre_imu_record_time = 0;
float pre_SP = 0;

float ax_l[DATA_Q_SIZE + 5]= {};
// float ay_l[DATA_Q_SIZE + 5];
// float az_l[DATA_Q_SIZE + 5];
// float gx_l[DATA_Q_SIZE + 5];
// float gy_l[DATA_Q_SIZE + 5];
float gz_l[DATA_Q_SIZE + 5] ={};


void push_in_value(float * list, float value)
{
  for(int i=0;i<DATA_Q_SIZE-1;i++)
  {
    list[i] = list[i+1];
  }
  list[DATA_Q_SIZE-1] = value;
}

float calculate_integral(double * x, double * y, float start_x, float end_x, int samples)
{
  float res = 0.00;

  float valid_x[samples + 5] = {};
  float valid_y[samples + 5] = {};

  for(int i = 0; i < samples-1; i++)
  {
    if(x[i] < start_x && x[i+1] > start_x)
    {
      valid_x[0] = start_x;
      valid_y[0] =  1.000 * (start_x-x[i])/(x[i+1]-x[i]) * (y[i+1]-y[i]) + y[i];
      break;
    }
  }

  int valid_index = 1;
  for(int i = 0; i < samples-1; i++)
  {
    if( start_x < x[i] && x[i] < end_x)
    {
      valid_x[valid_index] = x[i];
      valid_y[valid_index] = y[i];
      valid_index = valid_index + 1;
    }
    if(x[i] > end_x)
    {
      break;
    }
  }

  for(int i = 0; i < samples-1; i++)
  {
    if(x[i] < end_x && x[i+1] > end_x)
    {
      valid_x[valid_index] =  1.000 * end_x;
      valid_y[valid_index] =  1.000 *(end_x-x[i])/(x[i+1]-x[i]) * (y[i+1]-y[i]) + y[i];
      break;
    }
  }
  
  for(int i = 1; i <= valid_index; i++)
  {
    res = res + 1.000 * ((valid_y[i-1]+valid_y[i]) * (valid_x[i]-valid_x[i-1]) / 2.00);
  }

  res = roundf(10000 * res) / 10000.00;
  return res;
}


float calculate_FI(float * acc_values)
{
  int samples = 128;
  
  int DATA_LENGTH = FI_DURATION * SAMPLE_RATE;
  while(samples > DATA_LENGTH)
  {
    samples = samples / 2;
  }

  double vImag[DATA_LENGTH] = {};
  double power[DATA_LENGTH] = {};
  double vReal[DATA_LENGTH] = {};
  
  //Serial.println("acc");
  for (int i = 0; i < DATA_LENGTH; i++) {
    vReal[i] = fabs(acc_values[i + DATA_Q_SIZE - DATA_LENGTH]);
    vImag[i] = 0;
    //Serial.println(vReal[i]);
  }

  arduinoFFT FFT = arduinoFFT(vReal, vImag, samples, SAMPLE_RATE);
  FFT.DCRemoval(); 
  //FFT.Windowing(FFT_WIN_TYP_HAMMING, FFT_FORWARD);
  FFT.Compute(FFT_FORWARD);
  FFT.ComplexToMagnitude();

  double computed_freq[samples + 5];
  double computed_power[samples + 5];

  for (int i = 0; i < samples; i++)
  {
    computed_freq[i] = ((i * 1.0 * SAMPLE_RATE) / samples);
    computed_power[i] = (vReal[i]) * (vReal[i]);

    // Serial.print(computed_freq[i]);
    // Serial.print("Hz, ");
    // Serial.println(computed_power[i]);
  }
  computed_power[0] = 0; // set DC computnnet to be 0

  double NU = calculate_integral(computed_freq,computed_power,3,8,samples);
  double DE = calculate_integral(computed_freq,computed_power,0.5,3,samples);
  float FI = NU/DE * 1.000;
  if(DE < 0.01 && NU < 0.01) FI = 0;
  else if(DE == 0) FI = NU;

  FI = bond(FI,FI_IQR,FI_MEAN);
  return (FI - FI_MEAN )/ FI_IQR;
  //return FI;
}

float calculate_SP(float * gyro_z)
{
  float SP = 0;
  if( fabs(gyro_z[DATA_Q_SIZE-3]) < fabs(gyro_z[DATA_Q_SIZE-2]) &&  
      fabs(gyro_z[DATA_Q_SIZE-2]) > fabs(gyro_z[DATA_Q_SIZE-1]) && 
      fabs(gyro_z[DATA_Q_SIZE-2]) >= SP_THRESHOLD)
    SP = fabs(gyro_z[DATA_Q_SIZE-2]);
  else
    SP = pre_SP;
  pre_SP = SP;

  SP = bond(SP,SP_IQR,SP_MEAN);
  return (SP- SP_MEAN)/SP_IQR;
  //return SP;
}

float calculate_Var(float * gyro_z) 
{   
  int n = 64;
  // Compute mean (average of elements) 
  double sum = 0; 
  
  for (int i = DATA_Q_SIZE - n; i < DATA_Q_SIZE; i++) sum += gyro_z[i];    
  double mean = (double)sum / (double)n; 
  // Compute sum squared differences with mean. 
  double sqDiff = 0; 
  for (int i = DATA_Q_SIZE - n; i < DATA_Q_SIZE; i++)
      sqDiff += (gyro_z[i] - mean) * (gyro_z[i] - mean); 
  float Var = (float)sqDiff / n; 
  
  Var = bond(Var,VAR_IQR,VAR_MEAN);
  return (Var-VAR_MEAN)/VAR_IQR;
  //return Var;
} 

float bond(float var, float brounder, float mean)
{
  if(var > mean+brounder)
  {
    return mean+brounder;
  }
  if(var < mean-brounder)
  {
    return mean-brounder;
  }
  return var;
}

void setup() {
  tflite::InitializeTarget();

  Serial.begin(9600);
  // while (!Serial);
  // Serial.println("Started");

  if (!IMU.begin()) {
    Serial.println("Failed to initialize IMU!");
    while (1);
  }

  // Serial.print("Accelerometer sample rate = ");
  // Serial.print(IMU.accelerationSampleRate());
  // Serial.println("Hz");

  pinMode(BIO_FEEDBACK_PIN, OUTPUT);
  pinMode(RED, OUTPUT);
  pinMode(BLUE, OUTPUT);
  pinMode(GREEN, OUTPUT);
  pinMode(LED_PWR, OUTPUT);

  // Initialize the TensorFlow Lite interpreter
  my_model = tflite::GetModel(mlp_model);
  
  if (my_model->version() != TFLITE_SCHEMA_VERSION) {
    MicroPrintf(
        "Model provided is schema version %d not equal "
        "to supported version %d.",
        my_model->version(), TFLITE_SCHEMA_VERSION);
    return;
  }

  static tflite::AllOpsResolver resolver;

  // Build an interpreter to run the model with.
  static tflite::MicroInterpreter static_interpreter(
      my_model, resolver, tensor_arena, kTensorArenaSize);
  interpreter = &static_interpreter;

  // Allocate memory from the tensor_arena for the model's tensors.
  TfLiteStatus allocate_status = interpreter->AllocateTensors();
  if (allocate_status != kTfLiteOk) {
    MicroPrintf("AllocateTensors() failed");
    return;
  }

  // Obtain pointers to the model's input and output tensors.
  input = interpreter->input(0);
  output = interpreter->output(0);

  // Serial.println("Setup End");

  digitalWrite(BLUE,1);
  digitalWrite(RED,1);
  digitalWrite(GREEN,1);

  push_in_value(gz_l,0.0);
  push_in_value(gz_l,0.0);
  push_in_value(gz_l,0.0);

  delay(500); // wait for IMU to be ready
  START_TIME = millis();
}

#define max_count 6000

long times[max_count+5] = {};
float ax_ll[max_count+5] = {};
float gz_ll[max_count+5] = {};
float fi_ll[max_count+5] = {};
float sp_ll[max_count+5] = {};
float var_ll[max_count+5] = {};
// float mlp_ll[max_count+5] = {};
// float label_ll[max_count+5]= {};

int count = 0;


void loop() {
  long cur_time = millis();
  if(cur_time >= pre_imu_record_time + SAMPLE_INTERVAL_MS)
  {
    // Serial.println("Loop begin record data");
    pre_imu_record_time = cur_time;
    IMU.readAcceleration(ax, ay, az);
    IMU.readGyroscope(gx, gy, gz);
    // Serial.println((String)(millis() - start_time) + "," + ax + "," + ay + "," + az + "," + gx + "," + gy + "," + gz  ); 
    // Serial.println("Read data");
    push_in_value(ax_l,ax);
    //push_in_value(ay_l,ay);
    //push_in_value(az_l,az);
    //push_in_value(gx_l,gx);
    //push_in_value(gy_l,gy);
    push_in_value(gz_l,gz);
    // Serial.println("pushed data");

    calculate_SP(gz_l); // calculate SP first to get the pre_sp

    if(cur_time >= START_TIME + SAMPLE_INTERVAL_MS * (DATA_Q_SIZE + 5))
    { 

      float FI = calculate_FI(ax_l);
      float SP = calculate_SP(gz_l);
      float Var = calculate_Var(gz_l);
      // Serial.println("calculated");
      
      // Perform inference with your input data
      input->data.f[0] = FI;
      input->data.f[1] = SP;
      input->data.f[2] = Var;

      // Run inference, and report any error
      TfLiteStatus invoke_status = interpreter->Invoke();
      if (invoke_status != kTfLiteOk) {
        MicroPrintf("Invoke failed");
        return;
      }
      
      float output_data = output->data.f[0];
      // Serial.println(output_data);

      if (output_data>0.5)
      {
        digitalWrite(BIO_FEEDBACK_PIN,1);
        digitalWrite(RED,0);
        digitalWrite(GREEN,1);
        digitalWrite(BLUE,1);
      }
      else
      {
        digitalWrite(BIO_FEEDBACK_PIN,0);
        digitalWrite(RED,1);
        digitalWrite(GREEN,0);
        digitalWrite(BLUE,1);
      }

      // Output the results (in this case, a single value)
      // Serial.println(output_data);

      // Serial.print(FI);
      // Serial.print(" ");
      // Serial.print(SP);
      // Serial.print(" ");
      // Serial.println(Var);
    }
  }
}