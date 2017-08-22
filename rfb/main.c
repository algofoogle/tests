#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <stdarg.h>
#include <unistd.h>
#include <errno.h>

#define PORT 5900

#define MAXPENDING 5

#define RFB_TCP_BUFFER_INIT   1024

#define U8 unsigned char
#define U16 unsigned short
#define U32 unsigned int

#define BUILD_BUG_ON(condition) extern char _BUILD_BUG_ON_ [ sizeof(char[1 - 2*!!(condition)]) ]

BUILD_BUG_ON(sizeof(U8) != 1);
BUILD_BUG_ON(sizeof(U16) != 2);
BUILD_BUG_ON(sizeof(U32) != 4);

enum {
  RFB_SEC_INVALID = 0,
  RFB_SEC_NONE = 1,
  RFB_SEC_VNC = 2,
};


typedef struct {
  U8 bpp;
  U8 depth;
  U8 big_endian;
  U8 true_colour;
  U8 r_max[2];
  U8 g_max[2];
  U8 b_max[2];
  U8 r_shift;
  U8 g_shift;
  U8 b_shift;
  U8 _padding[3];
} pixel_format;

typedef struct {
  U8 width[2];
  U8 height[2];
  pixel_format format;
  U8 name_length[4];
  U8 name[0];
} server_init;


int Send(int sock, char* data, int len, int flags)
{
  int i;
  for (i=0; i<len; ++i) { printf("%02X ",(unsigned char)data[i]); }
  printf("\n");
  return send(sock, data, len, flags);
}


int SOCK_printf(int sock, const char *fmt, ...)
{
  va_list ap;
  int size = 0;
  char *pstr = NULL;
  // Determine required size:
  va_start(ap, fmt);
  size = vsnprintf(pstr, size, fmt, ap);
  va_end(ap);
  if (size < 0) { return size; }
  // Allocate buffer for string:
  ++size; // For trailing NUL.
  pstr = malloc(size);
  if (!pstr) { return -1; }
  // Generate final string:
  va_start(ap, fmt);
  size = vsnprintf(pstr, size, fmt, ap);
  if (size >= 0)
  {
    // Send the string, if all is OK:
    size = Send(sock, pstr, size, 0);
  }
  free(pstr);
  return size;
}


int SOCK_SendU8(int sock, unsigned int value)
{
  unsigned char buffer[1];
  buffer[0] = value & 0xFFL;
  return Send(sock, buffer, sizeof(buffer), 0);
}


int SOCK_SendU16(int sock, unsigned int value)
{
  unsigned char buffer[2];
  buffer[1] = value & 0xFFL; value >>= 8;
  buffer[0] = value & 0xFFL;
  return Send(sock, buffer, sizeof(buffer), 0);
}


int SOCK_SendU32(int sock, unsigned int value)
{
  unsigned char buffer[4];
  buffer[3] = value & 0xFFL; value >>= 8;
  buffer[2] = value & 0xFFL; value >>= 8;
  buffer[1] = value & 0xFFL; value >>= 8;
  buffer[0] = value & 0xFFL;
  return Send(sock, buffer, sizeof(buffer), 0);
}


typedef struct {
  int sock;
  char *buffer;
  int size;
  int len;
  int offset;
} rfb_conn;


int RFB_OpenClient(int sock, rfb_conn *pconn)
{
  memset(pconn, 0, sizeof(rfb_conn));
  pconn->len = 0;
  pconn->offset = 0;
  pconn->sock = sock;
  pconn->size = RFB_TCP_BUFFER_INIT;
  pconn->buffer = malloc(pconn->size);
  if (!pconn->buffer)
  {
    return -1;
  }
  // Send protocol version:
  SOCK_printf(sock, "RFB 003.003\n");
  return 0;
}


void RFB_CloseClient(rfb_conn *pc)
{
  close(pc->sock);
  if (pc->buffer)
  {
    free(pc->buffer);
    pc->buffer = NULL;
  }
  pc->size = 0;
  pc->len = 0;
  pc->offset = 0;
}


// 'size' specifies how many new bytes we need available in our buffer.
int RFB_Realloc(rfb_conn *pc, int size)
{
  char *new_buffer = NULL;
  int tail = pc->offset + pc->len;
  int new_buffer_size;
  if (tail + size > pc->size)
  {
    new_buffer_size = pc->len + size;
    new_buffer = malloc(new_buffer_size);
    if (!new_buffer)
    {
      return -1;
    }
    memcpy(new_buffer, pc->buffer+pc->offset, new_buffer_size);
    free(pc->buffer);
    pc->buffer = new_buffer;
    pc->size = new_buffer_size;
    pc->offset = 0;
  }
  return 0;
}


// 'size' specifies how many buffered bytes we expect:
int RFB_Expecting(rfb_conn *pc, int size)
{
  int overflow = (pc->offset + size) - pc->size;
  if (overflow > 0)
  {
    return RFB_Realloc(pc, overflow);
  }
  return 0;
}


char *RFB_WaitFor(rfb_conn *pc, int bytes)
{
  if (RFB_Expecting(pc, bytes) < 0)
  {
    return NULL;
  }
  int underrun;
  int incoming;
  while ( (underrun = bytes - pc->len) > 0)
  {
    incoming = recv(pc->sock, (void*)(pc->buffer+pc->offset+pc->len), underrun, 0);
    if (!incoming)
    {
      printf("No data?\n");
      return NULL;
    }
    if (incoming < 0)
    {
      // Failed:
      printf("Failed\n");
      return NULL;
    }
    if (incoming > underrun)
    {
      // OK, but more bytes available than what we're waiting for:
      incoming = underrun;
    }
    pc->len += incoming;
  }
  // OK:
  char *out = pc->buffer + pc->offset;
  pc->offset += bytes;
  pc->len -= bytes;
  return out;
}


int RFB_WaitForU8(rfb_conn *pc, unsigned int *value)
{
  char* data = RFB_WaitFor(pc, 1);
  if (!data)
  {
    return -1;
  }
  *value = (unsigned int)data[0];
  return 0;
}


int RFB_ServerInit(rfb_conn *pc, int width, int height, char *name)
{
  server_init *si;
  int name_length = strlen(name);
  int server_init_data_length = sizeof(server_init) + name_length;
  // Allocate extra bytes for server name:
  si = (server_init*)malloc(server_init_data_length);
  if (!si)
  {
    return -1;
  }
  si->width[1] = width & 0xFFL; width >>= 8;
  si->width[0] = width & 0xFFL;
  si->height[1] = height & 0xFFL; height >>= 8;
  si->height[0] = height & 0xFFL;
  memcpy(si->name, name, name_length);
  si->name_length[3] = name_length & 0xFFL; name_length >>= 8;
  si->name_length[2] = name_length & 0xFFL; name_length >>= 8;
  si->name_length[1] = name_length & 0xFFL; name_length >>= 8;
  si->name_length[0] = name_length & 0xFFL;
  si->format.bpp = 32;
  si->format.depth = 24;
  si->format.big_endian = 1;
  si->format.true_colour = 1;
  si->format.r_max[1] = 255;
  si->format.r_max[0] = 0;
  si->format.g_max[1] = 255;
  si->format.g_max[0] = 0;
  si->format.b_max[1] = 255;
  si->format.b_max[0] = 0;
  si->format.r_shift = 16;
  si->format.g_shift = 8;
  si->format.b_shift = 0;
  return Send(pc->sock, (char*)si, server_init_data_length, 0);
}



int RFB_FramebufferUpdate(rfb_conn *pc)
{
  int s = pc->sock;
  printf("(RFB_FramebufferUpdate)\n");
  static int step = 0;
  unsigned char raw[] = {
    0,
    0,
    0,1,
    0,10+step,
    0,20+step,
    0,30+step,
    0,40+step,
    0,0,0,2,
    0,0,0,1,
    0xFF,0xBB,0x66,0, // BGR0
    0x33,0x55,0x77,0, // BGR0
    0,5,
    0,6,
    0,7,
    0,8,
  };
  ++step;
  return Send(s, (char*)raw, sizeof(raw), 0);
  // SOCK_SendU8(s, 0); // message-type (FramebufferUpdate).
  // SOCK_SendU8(s, 0); // padding.
  // SOCK_SendU16(s, 1); // 1 rectangle.
  // // Rectangle:
  // SOCK_SendU16(s, 10); // x
  // SOCK_SendU16(s, 20); // y
  // SOCK_SendU16(s, 30); // width
  // SOCK_SendU16(s, step++); // height
  // SOCK_SendU32(s, 2); // RRE encoding.
  // // RRE:
  // SOCK_SendU32(s, 1); // Zero subrectangle(s).
  // SOCK_SendU32(s, 0x00808182); // Background.
  // // Subrectangle:
  // SOCK_SendU32(s, 0x00838485); // Colour.
  // SOCK_SendU16(s, 5); // x
  // SOCK_SendU16(s, 6); // y
  // SOCK_SendU16(s, 7); // width
  // SOCK_SendU16(s, 8); // height
  return -1;
}



void RFB_HandleClient(int sock)
{
  rfb_conn conn;
  int size;
  unsigned int value;
  char ver_string[13] = {0};
  char *tmp;
  printf("Accepted connection %d\n", sock);
  if (RFB_OpenClient(sock, &conn) < 0)
  {
    printf("RFB_OpenClient failed\n");
    return;
  }
  do { // Dummy loop to make 'break' easier.
    if (NULL == (tmp = RFB_WaitFor(&conn, 12)))
    {
      printf("Didn't get client version string\n");
      break;
    }
    memcpy(ver_string, tmp, 12);
    printf("Client version: %s", ver_string);
    // Send required security type:
    SOCK_SendU32(sock, RFB_SEC_NONE);
    // Wait for client to send init:
    if (RFB_WaitForU8(&conn, &value) < 0)
    {
      printf("Didn't get ClientInit\n");
      break;
    }
    printf("ClientInit shared flag: %d\n", value);
    RFB_ServerInit(&conn, 640, 480, "Anton's Test Server");
    RFB_FramebufferUpdate(&conn);
    sleep(1);
    RFB_FramebufferUpdate(&conn);
    sleep(1);
    RFB_FramebufferUpdate(&conn);
    printf("Wrapping up...\n");
    sleep(3);
  } while (0);
  printf("Closing connection %d\n", sock);
  RFB_CloseClient(&conn);
}


int main(int argc, char **argv)
{
  int server_socket, client_socket;
  struct sockaddr_in server_host, client_host;
  server_socket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  memset(&server_host, 0, sizeof(server_host));
  server_host.sin_family = AF_INET;
  server_host.sin_addr.s_addr = htonl(INADDR_ANY);
  server_host.sin_port = htons(PORT);
  bind(server_socket, (struct sockaddr*)&server_host, sizeof(server_host));
  listen(server_socket, MAXPENDING);  // Last arg is our connection queue limit.
  while (1)
  {
    unsigned int client_host_len = sizeof(client_host);
    // Block, waiting to accept a new connection:
    printf("Awaiting connection...\n");
    client_socket = accept(server_socket, (struct sockaddr*)&client_host, &client_host_len);
    RFB_HandleClient(client_socket);
  }
}
