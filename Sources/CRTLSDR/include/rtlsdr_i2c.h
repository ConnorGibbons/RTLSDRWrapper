#ifndef __I2C_H
#define __I2C_H

int rtlsdr_check_dongle_model(void *dev, char *manufact_check, char *product_check);
#ifndef __swift__
int rtlsdr_set_bias_tee_gpio(void *dev, int gpio, int on);
#endif
uint32_t rtlsdr_get_tuner_clock(void *dev);
int rtlsdr_i2c_write_fn(void *dev, uint8_t addr, uint8_t *buf, int len);
int rtlsdr_i2c_read_fn(void *dev, uint8_t addr, uint8_t *buf, int len);

#endif
