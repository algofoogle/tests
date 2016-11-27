/* tests/esp8266/06/demo.c:
 * Trying to implement better event handling and sending UDP packets.
 */

/* For more info, see:
 * http://blog.mark-stevens.co.uk/2015/06/udp-on-the-esp01-esp8266-development-board/
 */

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

// Strings:
#define S_WIFI        "WIFI event: "
#define S_WIFI_UP     S_WIFI "Connected to SSID '%s', channel %d\n"
#define S_WIFI_DOWN   S_WIFI "Disconnected from SSID '%s'. Reason: %d\n"
#define S_WIFI_AUTH   S_WIFI "Auth mode changed from %d to %d\n"
#define S_WIFI_IP     S_WIFI "Got IP: " IPSTR "; Mask: " IPSTR "; GW: " IPSTR "\n"
#define S_WIFI_UNK    S_WIFI "Unhandled event 0x%x\n"

// System OS Task-handling stuff:
#define MY_TASK_PRIORITY  USER_TASK_PRIO_0
#define MY_TASK_QUEUE_LEN 5 // How deep does this queue really need to be?
os_event_t my_task_queue[MY_TASK_QUEUE_LEN];

// Create an espconn structure for UDP purposes.
//NOTE: I've found that if this is a local variable in
// a function, espconn_sendto() crashes when using it.
// I guess espconn_sendto() doesn't like it being on the
// stack for some reason?
LOCAL struct espconn udp_conn;

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

  // Set the WIFI event handler.
  // This will notify us when we're connected, so
  // we can immediately react to it. This is an alternative
  // to, say, setting a timer to check our connection status.
  // This was just to prove it could be done; I think the
  // timer might be a better approach just as it gives us a
  // meaningful structure in which to set a timeout and
  // decide on something to do instead, rather than just
  // waiting/hanging indefinitely.
  wifi_set_event_handler_cb(handle_wifi_event);

  // Define our WiFi DHCP client hostname:
  wifi_station_set_hostname("ESP-Test06");
  // Disable auto-connect:
  wifi_station_set_auto_connect(0);
  // Enable automatic re-connection:
  wifi_station_set_reconnect_policy(1);
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
      // Once we're connected, trigger our Task that will send
      // UDP packets:
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
  // We'll broadcast to all hosts on the network:
  const char remote_ip[4] = {255,255,255,255};
  os_printf("(handle_my_task was called)\n");
  char hello[] = "Hello!\n";
  sint8 r;
  udp_conn.type = ESPCONN_UDP;
  // Does udp->proto.udp get freed automatically??
  udp_conn.proto.udp = (esp_udp *)os_zalloc(sizeof(esp_udp));
  udp_conn.proto.udp->local_port = espconn_port();
  udp_conn.proto.udp->remote_port = 12344;
  os_memcpy(udp_conn.proto.udp->remote_ip, remote_ip, 4);

  if ((r = espconn_create(&udp_conn)))
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
  udp_conn.proto.udp->remote_port = 12344;
  os_memcpy(udp_conn.proto.udp->remote_ip, remote_ip, 4);

  if ((r = espconn_sendto(&udp_conn, hello, sizeof(hello))))
  {
    os_printf("espconn_sendto FAILED with: %d\n", r);
  }
  else
  {
    os_printf("espconn_sendto succeeded.\n");
    if ((r = espconn_delete(&udp_conn)))
    {
      os_printf("espconn_delete FAILED with: %d\n", r);
    }
    else
    {
      os_printf("UDP packet sent as expected: %s\n", hello);
      os_printf("(%d bytes)", sizeof(hello)-1);
    }
  }
}
