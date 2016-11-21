/* tests/esp8266/04/blinky_pwm.c
 * Basic manual PWM example.
 */

#include "ets_sys.h"
#include "osapi.h"
#include "gpio.h"
#include "os_type.h"

// Refresh rate is 1000/16 => 62.5Hz:
#define PWM_STEPS 16
// Pulsating rate is 62.5 / PWM_STEPS / PWM_DELAY / 2 => 0.651Hz
// (39.0625 pulses per minute):
#define PWM_DELAY 3

static const int pin = 1;
static volatile os_timer_t some_timer;
static int duty = 0;
static int step = 0;
static int dir = 1;
static int repeat = 0;

void some_timerfunc(void *arg)
{
  if (++step > PWM_STEPS)
  {
    // We reached the PWM step count. Do we need to adjust the duty cycle?
    // so adjust the duty cycle as needed:
    step = 0;
    if (duty == PWM_STEPS)
    {
      // Start going down.
      dir = -1;
    }
    else if (duty == 0)
    {
      // Start going up again.
      dir = 1;
      os_printf("cycle...\n");
    }
    if (++repeat >= PWM_DELAY)
    {
      repeat = 0;
      duty += dir;
    }
  }
  if (step > duty)
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
