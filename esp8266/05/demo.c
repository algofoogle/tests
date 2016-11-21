#include "ets_sys.h"
#include "osapi.h"
#include "gpio.h"
#include "os_type.h"
#include "user_interface.h"

// SSID and password are in here:
#include "user_config.h"

static void my_task(os_event_t* events);

#define TASK_QUEUE_LENGTH 1

// Create a set of os_event_t objects in memory,
// which is our queue of task messages.
os_event_t task_queue[TASK_QUEUE_LENGTH];


// Init function:
void ICACHE_FLASH_ATTR user_init()
{
  char ssid[32] = SSID;
  char password[64] = SSID_PASSWORD;
  struct station_config wifi_conf;


  // Set baud rate of debug port:
  uart_div_modify(0,UART_CLK_FREQ / 115200);

  os_printf("Hello\r\n");
  os_printf("\r\nDEBUG: SDK version:%s\n", system_get_sdk_version());
  os_printf("DEBUG: Autoconnect: %u\n", wifi_station_get_auto_connect());

  // Define our client hostname:
  wifi_station_set_hostname("AntonESP");

  // Set station mode (i.e. we're a WiFi client):
  wifi_set_opmode(1);
  // Set AP settings:
  os_memcpy(&wifi_conf.ssid, ssid, sizeof(ssid));
  os_memcpy(&wifi_conf.password, password, sizeof(password));
  // Apply settings and let the ESP8266 connect:
  wifi_station_set_config(&wifi_conf);

  // Create an OS task:
  system_os_task(my_task, USER_TASK_PRIO_0, task_queue, TASK_QUEUE_LENGTH);
  system_os_post(USER_TASK_PRIO_0, 0, 0);
}

static void ICACHE_FLASH_ATTR my_task(os_event_t* events)
{
  static int index = 0;
  ++index;
  os_printf("%d: Hello\r\n", index);
  os_delay_us(1000000);
  system_os_post(USER_TASK_PRIO_0, 0, 0);
}
