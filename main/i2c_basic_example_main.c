/*
 * SPDX-FileCopyrightText: 2024 Espressif Systems (Shanghai) CO LTD
 *
 * SPDX-License-Identifier: Unlicense OR CC0-1.0
 */
/* i2c - Simple Example

   Simple I2C example that shows how to initialize I2C
   as well as reading and writing from and to registers for a sensor connected over I2C.

   The sensor used in this example is a MPU9250 inertial measurement unit.
*/
#include <stdio.h>
#include "sdkconfig.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h" 
#include "driver/i2c_master.h"
#include "driver/gpio.h"
#include "esp_timer.h"

static const char *TAG = "example";

#define BUZZER_PIN                  5       /*!< GPIO number used for Buzzer */
#define I2C_MASTER_SCL_IO           6       /*!< GPIO number used for I2C master clock */
#define I2C_MASTER_SDA_IO           4       /*!< GPIO number used for I2C master data  */
#define I2C_MASTER_NUM              I2C_NUM_0                   /*!< I2C port number for master dev */
#define I2C_MASTER_FREQ_HZ          CONFIG_I2C_MASTER_FREQUENCY /*!< I2C master clock frequency */
#define I2C_MASTER_TX_BUF_DISABLE   0                           /*!< I2C master doesn't need buffer */
#define I2C_MASTER_RX_BUF_DISABLE   0                           /*!< I2C master doesn't need buffer */
#define I2C_MASTER_TIMEOUT_MS       1000

#define ICM42670P_SENSOR_ADDR       0x68        /*!< Address of the ICM-42670-P sensor (AD0 low) */
#define ICM42670P_WHO_AM_I_REG_ADDR 0x75        /*!< WHO_AM_I register address */
#define ICM42670P_PWR_MGMT_REG_ADDR 0x1F        /*!< PWR_MGMT_0 register address */
#define ICM42670P_ACCEL_DATA_REG    0x0B        /*!< ACCEL_DATA_X0 register address (start of accel data) */
#define ICM42670P_GYRO_DATA_REG     0x11        /*!< GYRO_DATA_X0 register address (start of gyro data) */

/**
 * @brief Read a sequence of bytes from an ICM-42670-P sensor register
 */
static esp_err_t icm42670p_register_read(i2c_master_dev_handle_t dev_handle, uint8_t reg_addr, uint8_t *data, size_t len)
{
    return i2c_master_transmit_receive(dev_handle, &reg_addr, 1, data, len, I2C_MASTER_TIMEOUT_MS / portTICK_PERIOD_MS);
}

/**
 * @brief Write a byte to an ICM-42670-P sensor register
 */
static esp_err_t icm42670p_register_write_byte(i2c_master_dev_handle_t dev_handle, uint8_t reg_addr, uint8_t data)
{
    uint8_t write_buf[2] = {reg_addr, data};
    return i2c_master_transmit(dev_handle, write_buf, sizeof(write_buf), I2C_MASTER_TIMEOUT_MS / portTICK_PERIOD_MS);
}

/**
 * @brief Read accelerometer and gyroscope data from ICM-42670-P
 */
static esp_err_t icm42670p_read_accel_gyro(i2c_master_dev_handle_t dev_handle, int16_t *accel, int16_t *gyro)
{
    uint8_t data[12];
    esp_err_t ret = icm42670p_register_read(dev_handle, ICM42670P_ACCEL_DATA_REG, data, 12);
    if (ret != ESP_OK) return ret;
    // Accel: X0,X1,Y0,Y1,Z0,Z1 (big endian)
    for (int i = 0; i < 3; ++i) {
        accel[i] = (int16_t)((data[i*2] << 8) | data[i*2+1]);
    }
    // Gyro: X0,X1,Y0,Y1,Z0,Z1
    for (int i = 0; i < 3; ++i) {
        gyro[i] = (int16_t)((data[6+i*2] << 8) | data[7+i*2]);
    }
    return ESP_OK;
}

/**
 * @brief i2c master initialization
 */
static void i2c_master_init(i2c_master_bus_handle_t *bus_handle, i2c_master_dev_handle_t *dev_handle)
{
    i2c_master_bus_config_t bus_config = {
        .i2c_port = I2C_MASTER_NUM,
        .sda_io_num = I2C_MASTER_SDA_IO,
        .scl_io_num = I2C_MASTER_SCL_IO,
        .clk_source = I2C_CLK_SRC_DEFAULT,
        .glitch_ignore_cnt = 7,
        .flags.enable_internal_pullup = true,
    };
    ESP_ERROR_CHECK(i2c_new_master_bus(&bus_config, bus_handle));

    i2c_device_config_t dev_config = {
        .dev_addr_length = I2C_ADDR_BIT_LEN_7,
        .device_address = ICM42670P_SENSOR_ADDR,
        .scl_speed_hz = I2C_MASTER_FREQ_HZ,
    };
    ESP_ERROR_CHECK(i2c_master_bus_add_device(*bus_handle, &dev_config, dev_handle));
}

void app_main(void)
{
    uint8_t whoami = 0;
    i2c_master_bus_handle_t bus_handle;
    i2c_master_dev_handle_t dev_handle;
    i2c_master_init(&bus_handle, &dev_handle);
    ESP_LOGI(TAG, "I2C initialized successfully");
    
    // Read WHO_AM_I register (should be 0x67 for ICM-42670-P)
    ESP_ERROR_CHECK(icm42670p_register_read(dev_handle, ICM42670P_WHO_AM_I_REG_ADDR, &whoami, 1));
    ESP_LOGI(TAG, "ICM-42670-P WHO_AM_I = 0x%02X", whoami);

    // Wake up the sensor (set PWR_MGMT_0 to 0x0F: accel+gyro in low noise mode)
    ESP_ERROR_CHECK(icm42670p_register_write_byte(dev_handle, ICM42670P_PWR_MGMT_REG_ADDR, 0x0F));
    vTaskDelay(pdMS_TO_TICKS(10));

    // Configure buzzer GPIO
    gpio_config_t buzzer_conf = {
        .pin_bit_mask = (1ULL << BUZZER_PIN),
        .mode = GPIO_MODE_OUTPUT,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE
    };
    gpio_config(&buzzer_conf);
    gpio_set_level(BUZZER_PIN, 0);

    int16_t accel[3], gyro[3];
    int64_t last_sample_time = esp_timer_get_time(); // us
    int64_t buzzer_start_time = 0;
    bool buzzer_active = false;
    int64_t last_buzzer_toggle = 0;
    bool buzzer_state = false;
    const int buzzer_duration_us = 100000; // 0.5s
    const int buzzer_toggle_us = 500; // 500us for ~1kHz

    while (true) {
        int64_t now = esp_timer_get_time();
        // IMU sampling at 50Hz (every 20ms)
        if (now - last_sample_time >= 20000) {
            last_sample_time = now;
            ESP_ERROR_CHECK(icm42670p_read_accel_gyro(dev_handle, accel, gyro));
            ESP_LOGI(TAG, "Accel: X=%d Y=%d Z=%d | Gyro: X=%d Y=%d Z=%d", accel[0], accel[1], accel[2], gyro[0], gyro[1], gyro[2]);
            // Check if any gyro magnitude exceeds 2000
            for (int j = 0; j < 3; ++j) {
                if (abs(gyro[j]) > 2000) {
                    buzzer_active = true;
                    buzzer_start_time = now;
                    last_buzzer_toggle = now;
                    buzzer_state = false;
                    break;
                }
            }
        }
        
        // Non-blocking buzzer control
        if (buzzer_active) {
            if (now - buzzer_start_time < buzzer_duration_us) {
                if (now - last_buzzer_toggle >= buzzer_toggle_us) {
                    buzzer_state = !buzzer_state;
                    gpio_set_level(BUZZER_PIN, buzzer_state ? 1 : 0);
                    last_buzzer_toggle = now;
                }
            } else {
                buzzer_active = false;
                gpio_set_level(BUZZER_PIN, 0);
            }
        }
        vTaskDelay(pdMS_TO_TICKS(1)); // yield to RTOS, minimal delay
    }

    ESP_ERROR_CHECK(i2c_master_bus_rm_device(dev_handle));
    ESP_ERROR_CHECK(i2c_del_master_bus(bus_handle));
    ESP_LOGI(TAG, "I2C de-initialized successfully");
}
