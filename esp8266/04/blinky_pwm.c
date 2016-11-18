#include "ets_sys.h"
#include "osapi.h"
#include "gpio.h"
#include "os_type.h"

static const int pin = 1;
static volatile os_timer_t some_timer;
static int duty = 0;
static int step = 0;
#define PWM_STEPS 10

void some_timerfunc(void *arg)
{
  if (++step > PWM_STEPS)
  {
    step = -PWM_STEPS;
    if (++duty > PWM_STEPS)
    {
      duty = -PWM_STEPS;
    }
  }
  // Squaring is just a lazy way to do abs():
  if (step*step > duty*duty)
  {
    // set gpio low
    gpio_output_set(0, (1 << pin), 0, 0);
  }
  else
  {
    // set gpio high
    gpio_output_set((1 << pin), 0, 0, 0);
  }
}

void ICACHE_FLASH_ATTR user_init()
{
  // init gpio sussytem
  gpio_init();

  // configure UART TXD to be GPIO1, set as output
  PIN_FUNC_SELECT(PERIPHS_IO_MUX_U0TXD_U, FUNC_GPIO1); 
  gpio_output_set(0, 0, (1 << pin), 0);

  // setup timer (1ms, repeating)
  os_timer_setfn(&some_timer, (os_timer_func_t *)some_timerfunc, NULL);
  os_timer_arm(&some_timer, 1, 1);
}
