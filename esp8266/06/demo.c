/* tests/esp8266/05/demo.c:
 * Main file for a basic WiFi client connection example, with
 * simple serial (UART) output at a configured rate of 115,200 baud.
 */

#include "ets_sys.h"
#include "osapi.h"
#include "gpio.h"
#include "os_type.h"
#include "user_interface.h"

// SSID and password are in here:
#include "user_config.h"

// Prototype for 'my_task' message processor callback:
static void my_task(os_event_t* events);

// Our queue will support a maximum of 1 message, at this stage:
#define TASK_QUEUE_LENGTH 1

// Create a buffer of os_event_t objects in memory,
// which is our queue of task messages.
os_event_t task_queue[TASK_QUEUE_LENGTH];


// Init function:
void ICACHE_FLASH_ATTR user_init()
{
  char ssid[32] = SSID;
  char password[64] = SSID_PASSWORD;
  struct station_config wifi_conf;

  // Set baud rate of debug port:
  uart_div_modify(0, UART_CLK_FREQ / 115200);

  os_printf("Hello from ESP8266 test 05!\n");
  os_printf("DEBUG: SDK version: %s\n", system_get_sdk_version());
  os_printf("DEBUG: Autoconnect: %u\n", wifi_station_get_auto_connect());

  // Define our WiFi client hostname:
  wifi_station_set_hostname("AntonESP");

  // Set station mode (i.e. we're a WiFi client):
  wifi_set_opmode(1);
  // Set AP settings:
  os_memcpy(&wifi_conf.ssid, ssid, sizeof(ssid));
  os_memcpy(&wifi_conf.password, password, sizeof(password));
  // Apply settings and let the ESP8266 do its auto-connect:
  wifi_station_set_config(&wifi_conf);

  // Create an OS task, for Priority 0, giving it our message queue to use:
  system_os_task(my_task, USER_TASK_PRIO_0, task_queue, TASK_QUEUE_LENGTH);
  // Send a message to Priority 0, which 'my_task' will handle:
  system_os_post(USER_TASK_PRIO_0, 0, 0);
}

// Our message handler for Priority 0 message events:
static void ICACHE_FLASH_ATTR my_task(os_event_t* event)
{
  // Display a message based on our message's parameter:
  os_printf("my_task sequence %d: Hello\r\n", event->par);
  // Wait 1sec:
  os_delay_us(1000000);
  // Post another message, this time with the parameter incremented:
  system_os_post(USER_TASK_PRIO_0, 0, event->par+1);
}
