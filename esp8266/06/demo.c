/* tests/esp8266/06/demo.c:
 * Trying to implement better event handling and sending UDP packets.
 */

/* For more info, see:
 * http://blog.mark-stevens.co.uk/2015/06/udp-on-the-esp01-esp8266-development-board/
 */

//#include "at_custom.h"

#include "ets_sys.h"
#include "osapi.h"
#include "gpio.h"
#include "os_type.h"
#include "mem.h"
#include "user_interface.h"
#include "ip_addr.h"
#include "espconn.h"

// SSID and password are in here:
#include "user_config.h"

#define S_WIFI        "WIFI event: "
#define S_WIFI_UP     S_WIFI "Connected to SSID '%s', channel %d\n"
#define S_WIFI_DOWN   S_WIFI "Disconnected from SSID '%s'. Reason: %d\n"
#define S_WIFI_AUTH   S_WIFI "Auth mode changed from %d to %d\n"
#define S_WIFI_IP     S_WIFI "Got IP: " IPSTR "; Mask: " IPSTR "; GW: " IPSTR "\n"
#define S_WIFI_UNK    S_WIFI "Unhandled event 0x%x\n"

#define MY_TASK_PRIORITY  USER_TASK_PRIO_0
#define MY_TASK_QUEUE_LEN 5 // How deep does this queue really need to be?

os_event_t my_task_queue[MY_TASK_QUEUE_LEN];


// Prototypes of functions...
static void ICACHE_FLASH_ATTR handle_wifi_event(System_Event_t*);
static void ICACHE_FLASH_ATTR handle_system_ready();
static void ICACHE_FLASH_ATTR handle_my_task(os_event_t*);

// Init function. We set up the system here, including event
// handlers, and then leave it up to those events to do
// all of the heavy lifting for us.
void ICACHE_FLASH_ATTR user_init()
{
  // Set UART to work at 115,200 baud and say hello:
  uart_div_modify(0, UART_CLK_FREQ / 115200);
  os_printf("\n\nESP8266 test 06 booting...\n");

  #if 0
  //NOTE: These lines can be used to reset wifi
  // settings in the flash, disabling auto-connect, so
  // we can get total session-level control over all that.
  os_printf("Clearing wifi settings from flash...\n");
  // Wipe wifi config from flash:
  system_restore();
  // Disable wifi auto-connect, setting it in flash:
  os_printf("Setting wifi STATION (client) mode...\n");
  wifi_set_opmode(STATION_MODE);
  #endif

  os_printf("Disabling wifi auto-connect flash setting...\n");
  wifi_station_set_auto_connect(0);

  // Set the WIFI event handler:
  wifi_set_event_handler_cb(handle_wifi_event);

  #if 1
  // Define our WiFi DHCP client hostname:
  wifi_station_set_hostname("ESP-Test06");
  // Configure wifi settings so we can just be a normal wifi client.
  // Note that the ..._current version of this function DOESN'T
  // write these settings to flash:
  wifi_set_opmode_current(STATION_MODE);
  char ssid[32] = SSID;
  char password[64] = SSID_PASSWORD;
  struct station_config wifi_conf;
  wifi_conf.bssid_set = 0;
  os_memcpy(&wifi_conf.ssid, ssid, sizeof(ssid));
  os_memcpy(&wifi_conf.password, password, sizeof(password));
  wifi_station_set_config_current(&wifi_conf);
  #endif

  // Create a system task that will be our main worker:
  system_os_task(handle_my_task, MY_TASK_PRIORITY, my_task_queue, MY_TASK_QUEUE_LEN);

  // Set a system init completion callback:
  system_init_done_cb(handle_system_ready);
  os_printf("user_init done. Waiting for system init...\n");
}


// When a WiFi event occurs, wifi_set_event_handler_cb is
// responsible for making sure our handle_wifi_event function
// gets called to let us know specifically what happened.
static void ICACHE_FLASH_ATTR handle_wifi_event(System_Event_t* ev)
{
  switch (ev->event) {
    case EVENT_STAMODE_CONNECTED:
      os_printf(S_WIFI_UP, ev->event_info.connected.ssid, ev->event_info.connected.channel);
      break;
    case EVENT_STAMODE_DISCONNECTED:
      os_printf(S_WIFI_DOWN, ev->event_info.disconnected.ssid, ev->event_info.disconnected.reason);
      break;
    case EVENT_STAMODE_AUTHMODE_CHANGE:
      os_printf(S_WIFI_AUTH, ev->event_info.auth_change.old_mode, ev->event_info.auth_change.new_mode);
      break;
    case EVENT_STAMODE_GOT_IP:
      os_printf(
        S_WIFI_IP,
        IP2STR(&ev->event_info.got_ip.ip),
        IP2STR(&ev->event_info.got_ip.mask),
        IP2STR(&ev->event_info.got_ip.gw)
      );
      system_os_post(MY_TASK_PRIORITY, 0, 0);
      break;
    default:
      os_printf(S_WIFI_UNK, ev->event);
      break;
  }
}


// When the ESP8266 core system has finished initialising itself,
// system_init_done_cb is responsible for making sure our
// handle_system_ready function gets called to let us know
// that we can start up our main application-level stuff.
static void ICACHE_FLASH_ATTR handle_system_ready()
{
  os_printf("System init done. Starting app processes...\n");
  // Connect wifi:
  wifi_station_connect();
  // Call our task handler. Not sure we really need to do this,
  // but it seems fine for now :)
  // system_os_post(MY_TASK_PRIORITY, 0, 0);
}


// Our message handler for Priority 0 message events:
static void ICACHE_FLASH_ATTR handle_my_task(os_event_t* ev)
{
  const char remote_ip[4] = {10,1,1,255};
  os_printf("(handle_my_task was called)\n");
  char hello[] = "Hello!\n";
  sint8 r;
  // Create an espconn structure for UDP purposes.
  struct espconn udp_conn_struct;
  struct espconn* udp = &udp_conn_struct;
  udp->type = ESPCONN_UDP;
  udp->state = ESPCONN_NONE;
  // Does udp->proto.udp get freed automatically??
  udp->proto.udp = (esp_udp *)os_zalloc(sizeof(esp_udp));
  udp->proto.udp->local_port = espconn_port();
  udp->proto.udp->remote_port = 12344;
  os_memcpy(udp->proto.udp->remote_ip, remote_ip, 4);

  if ((r = espconn_create(udp)))
  {
    os_printf("espconn_create FAILED with: %d\n", r);
    return;
  }
  else
  {
    os_printf("espconn_create succeeded\n");
  }

  // Have to repeat this before espconn_sendto (as espconn_create
  // will likely have modified it):
  udp->proto.udp->remote_port = 12344;
  os_memcpy(udp->proto.udp->remote_ip, remote_ip, 4);

  if ((r = espconn_sendto(udp, hello, 6)))
  {
    os_printf("espconn_sendto FAILED with: %d\n", r);
  }
  else
  {
    os_printf("espconn_sendto succeeded.\n");
    if ((r = espconn_delete(udp)))
    {
      os_printf("espconn_delete FAILED with: %d\n", r);
    }
    else
    {
      os_printf("UDP packet sent as expected: '%s' (%d bytes)\n", hello, sizeof(hello)-1);
    }
  }
}
