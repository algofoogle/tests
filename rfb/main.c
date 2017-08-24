#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <stdarg.h>
#include <unistd.h>
#include <errno.h>

#define PORT 5905

#define MAXPENDING 5

#define RFB_TCP_BUFFER_INIT   1024

#define U8 unsigned char
#define U16 unsigned short
#define U32 unsigned int
#define S32 int

#define BUILD_BUG_ON(condition) extern char _BUILD_BUG_ON_ [ sizeof(char[1 - 2*!!(condition)]) ]

#define Default(zzsrc,zzalt) ((zzsrc) ? (zzsrc) : (zzalt))

BUILD_BUG_ON(sizeof(U8) != 1);
BUILD_BUG_ON(sizeof(U16) != 2);
BUILD_BUG_ON(sizeof(U32) != 4);
BUILD_BUG_ON(sizeof(S32) != 4);

enum {
  RFB_SEC_INVALID = 0,
  RFB_SEC_NONE = 1,
  RFB_SEC_VNC = 2,
};


// This is used to tell GCC that we want our structs packed exactly
// as stated with no automatic padding/alignment:
#define PACKED __attribute__((packed))

#define B0(zzs) ((zzs)&0xFFL)
#define B1(zzs) ((zzs>>8)&0xFFL)
#define B2(zzs) ((zzs>>16)&0xFFL)
#define B3(zzs) ((zzs>>24)&0xFFL)

#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
#define RFB8(zzs) (zzs)
#define RFB16(zzs) ((B0(zzs)<<8) | (B1(zzs)))
#define RFB32(zzs) ((B0(zzs)<<24) | (B1(zzs)<<16) | (B2(zzs)<<8) | (B3(zzs)))
#else
#define RFB8(zzs) (zzs)
#define RFB16(zzs) ((zzs)&0xFFFFL)
#define RFB32(zzs) ((zzs)&0xFFFFFFFFL)
#endif


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
} PACKED pixel_format;

BUILD_BUG_ON(sizeof(pixel_format) != 16);


typedef struct {
  U8 _padding[3];
  pixel_format format;
} PACKED SetPixelFormat_t;

BUILD_BUG_ON(sizeof(SetPixelFormat_t) != 19);

#define DUMP_PIXEL_FORMAT(zzpf) \
printf(  \
  "BPP:          %d\n"        \
  "Depth:        %d\n"        \
  "Endianness:   %s\n"        \
  "True-colour:  %s\n"        \
  "Mask Red:     0x%04X\n"    \
  "Mask Green:   0x%04X\n"    \
  "Mask Blue:    0x%04X\n"    \
  "Shift Red:    %d\n"        \
  "Shift Green:  %d\n"        \
  "Shift Blue:   %d\n",  \
  (zzpf)->bpp,  \
  (zzpf)->depth,  \
  (zzpf)->big_endian ? "BIG" : "little",  \
  (zzpf)->true_colour ? "YES" : "no",  \
  (unsigned int)RFB16(*(U16*)((zzpf)->r_max)),  \
  (unsigned int)RFB16(*(U16*)((zzpf)->g_max)),  \
  (unsigned int)RFB16(*(U16*)((zzpf)->b_max)),  \
  (zzpf)->r_shift,  \
  (zzpf)->g_shift,  \
  (zzpf)->b_shift  \
)


// Variable length:
typedef struct {
  U8 _padding[1];
  U16 count;
  S32 encodings[0]; // 'count' entries.
} PACKED SetEncodings_t;

BUILD_BUG_ON(sizeof(SetEncodings_t) != 3);


typedef struct {
  U8 incremental;
  U16 x;
  U16 y;
  U16 w;
  U16 h;
} PACKED FramebufferUpdateRequest_t;

typedef struct {
  U8 down;
  U8 _padding[2];
  U32 key;
} PACKED KeyEvent_t;

typedef struct {
  U8 button_mask;
  U16 x;
  U16 y;
} PACKED PointerEvent_t;

// Variable length:
typedef struct {
  U8 _padding[3];
  U32 len;
  char text[0]; // 'len' bytes.
} PACKED ClientCutText_t;


typedef struct {
  U8 width[2];
  U8 height[2];
  pixel_format format;
  U8 name_length[4];
  U8 name[0];
} PACKED server_init;


int Send(int sock, char *data, int len, int flags)
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
  return Send(sock, (char*)buffer, sizeof(buffer), 0);
}


int SOCK_SendU16(int sock, unsigned int value)
{
  unsigned char buffer[2];
  buffer[1] = value & 0xFFL; value >>= 8;
  buffer[0] = value & 0xFFL;
  return Send(sock, (char*)buffer, sizeof(buffer), 0);
}


int SOCK_SendU32(int sock, unsigned int value)
{
  unsigned char buffer[4];
  buffer[3] = value & 0xFFL; value >>= 8;
  buffer[2] = value & 0xFFL; value >>= 8;
  buffer[1] = value & 0xFFL; value >>= 8;
  buffer[0] = value & 0xFFL;
  return Send(sock, (char*)buffer, sizeof(buffer), 0);
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


#define RFB_WaitForStruct(zzconn,zzstruct)  ((zzstruct *)RFB_WaitFor((zzconn), sizeof(zzstruct)))


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
  DUMP_PIXEL_FORMAT(&si->format);
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


enum {
  STATE_HANDSHAKE,
  STATE_READY,
};


enum {
  kSetPixelFormat = 0,
  kSetEncodings = 2,
  kFramebufferUpdateRequest = 3,
  kKeyEvent = 4,
  kPointerEvent = 5,
  kClientCutText = 6,
};


#define BYTE_TO_BINARY_PATTERN "%c%c%c%c%c%c%c%c"
#define BYTE_TO_BINARY(byte)  \
  (byte & 0x80 ? '1' : '0'), \
  (byte & 0x40 ? '1' : '0'), \
  (byte & 0x20 ? '1' : '0'), \
  (byte & 0x10 ? '1' : '0'), \
  (byte & 0x08 ? '1' : '0'), \
  (byte & 0x04 ? '1' : '0'), \
  (byte & 0x02 ? '1' : '0'), \
  (byte & 0x01 ? '1' : '0') 

int nprint(char *prefix, char *str, int len, char *suffix)
{
  char *buffer = calloc(len+1, 0);
  if (!buffer)
  {
    return -1;
  }
  memcpy(buffer, str, len);
  int result = printf("%s%s%s", Default(prefix,""), buffer, Default(suffix,""));
  free(buffer);
  return result;
}


void DEBUG_HexDump(char *data, int len, char *heading)
{
  int i, j;
  char c;
  char cbuf[19];
  if (heading) printf("%s\n", heading);
  // Go line by line: 16 bytes at a time:
  for (i=0; i<len; i+=16)
  {
    printf("%04x: ", i);
    strcpy(cbuf, "|                |");
    // Process each byte out of the 16:
    for (j=0; j<16 && (i+j)<len; ++j)
    {
      c = data[i+j];
      printf("%02x%c", (unsigned char)c, (j==7) ? '-' : ' ');
      cbuf[1+j] = isprint(c) ? c : '.';
    }
    // Pad out, and print trailing ASCII representation:
    while (j++ < 16) printf("   ");
    printf(" %s\n", cbuf);
  }
}


#define HEXDUMP(zzhead,zzsrc,zzmul,zzextra) DEBUG_HexDump((char*)(zzsrc),sizeof(*(zzsrc))*(zzmul)+(zzextra),(zzhead))


#define CASE_PRINT(zzconst) case zzconst: { printf("%s", (#zzconst)); break; }


int RFB_Handshake(rfb_conn *pc)
{
  char *client_ver;
  unsigned int value;
  client_ver = RFB_WaitFor(pc, 12);
  if (!client_ver)
  {
    printf("Didn't get client version string\n");
    return -1;
  }
  nprint("Client version: ", client_ver, 12, "\n");
  // Send our required security type:
  SOCK_SendU32(pc->sock, RFB_SEC_NONE);
  // Expect ClientInit (share flag byte):
  if (RFB_WaitForU8(pc, &value) < 0)
  {
    printf("Didn't get ClientInit\n");
    return -1;
  }
  printf("ClientInit share flag: %d\n", value);
  // Send ServerInit:
  if (RFB_ServerInit(pc, 500, 500, "Anton's Test Server") < 0)
  {
    printf("ServerInit failed\n");
    return -1;
  }
  printf("ServerInit sent; ready for Client commands\n");
  return 0;
}


// int RFB_Handle_SetPixelFormat(rfb_conn *pc)
// {

// }

#define BEGIN_CLIENT_COMMAND_SET() {
#define CLIENT_COMMAND(zzcmd,zzvar) \
  } case k##zzcmd: { \
    zzcmd##_t *zzvar; \
    printf(#zzcmd); \
    zzvar = RFB_WaitForStruct(pc, zzcmd##_t); \
    if (!zzvar) { \
      printf(" - Failed!\n"); \
      return -1; \
    } \
    else
#define END_CLIENT_COMMAND_SET()  }

int RFB_WaitForClientCommand(rfb_conn *pc)
{
  // Wait for command [byte] from client:
  int size;
  unsigned int value;
  char ver_string[13] = {0};
  char *tmp;
  // printf("(RFB_WaitForClientCommand)\n");
  if (RFB_WaitForU8(pc, &value) < 0)
  {
    printf("Failed while waiting for client command: Disconnected?\n");
    return -1;
  }
  printf("Client command: ");
  switch (value)
  {
    BEGIN_CLIENT_COMMAND_SET();
    CLIENT_COMMAND(SetPixelFormat,m)
    {
      #warning TODO: Handle SetPixelFormat!
      printf(" - Not implemented\n");
      HEXDUMP("", m, 1, 0);
      DUMP_PIXEL_FORMAT(&m->format);
      break;
    }
    CLIENT_COMMAND(SetEncodings,m)
    {
      int count;
      S32 *encoding_types;
      HEXDUMP("", m, 1, 0);
      count = RFB16(m->count);
      if (count > 0)
      {
        // Get extra data:
        printf(" x %d", count);
        encoding_types = (S32*)RFB_WaitFor(pc, sizeof(S32)*count);
        if (!encoding_types)
        {
          printf(" - Failed getting %d encoding types!", count);
          return -1;
        }
      }
      #warning TODO: Handle SetEncodings!
      printf(" - Not implemented\n");
      HEXDUMP("", encoding_types, count, 0);
      break;
    }
    CLIENT_COMMAND(FramebufferUpdateRequest,m)
    {
      #warning TODO: Handle FramebufferUpdateRequest!
      printf(" - Not implemented\n");
      HEXDUMP("", m, 1, 0);
      break;
    }
    CLIENT_COMMAND(KeyEvent,m)
    {
      #warning TODO: Handle KeyEvent!
      printf(" - Not implemented\n");
      printf("Key '%c' %s", (char)RFB32(m->key), m->down ? "down" : "up");
      // HEXDUMP("", m, 1, 0);
      break;
    }
    CLIENT_COMMAND(PointerEvent,m)
    {
      #warning TODO: Handle PointerEvent!
      printf(" - Not implemented\n");
      printf("Pos: (%d,%d) - Buttons: "BYTE_TO_BINARY_PATTERN, (int)RFB16(m->x), (int)RFB16(m->y), BYTE_TO_BINARY(m->button_mask));
      // HEXDUMP("", m, 1, 0);
      break;
    }
    CLIENT_COMMAND(ClientCutText,m)
    {
      int len;
      char *text;
      len = m->len;
      if (len > 0)
      {
        // Get extra data:
        text = RFB_WaitFor(pc, sizeof(U8)*len);
        if (!text)
        {
          printf(" - Failed getting %d bytes!", len);
          return -1;
        }
        printf(" x %d byte(s)", len);
      }
      #warning TODO: Handle ClientCutText!
      printf(" - Not implemented");
      break;
    }
    END_CLIENT_COMMAND_SET();
    default:
    {
      printf("Unknown (0x%02X)", (U8)value);
      break;
    }
  }
  return value;
}


void RFB_HandleClient(int sock)
{
  rfb_conn conn;
  printf("Accepted connection %d\n", sock);
  if (RFB_OpenClient(sock, &conn) < 0)
  {
    printf("RFB_OpenClient failed\n");
    return;
  }
  int state = STATE_HANDSHAKE;
  int abort = 0;

  // RFB message loop:
  while (!abort)
  {
    switch (state)
    {
      case STATE_HANDSHAKE:
      {
        // Expecting version string from client, then ClientInit (share flag)...
        if (RFB_Handshake(&conn) < 0)
        {
          abort = 1;
          break;
        }
        state = STATE_READY;
        break;
      }
      case STATE_READY:
      {
        printf("ready...\n");
        if (RFB_WaitForClientCommand(&conn) < 0)
        {
          abort = 1;
          break;
        }
        
        printf("\n");
        break;
      }
    }
  }
  printf("Closing connection %d\n", sock);
  RFB_CloseClient(&conn);
}


int main(int argc, char **argv)
{
  int result;
  int server_socket, client_socket;
  struct sockaddr_in server_host, client_host;

  server_socket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (server_socket < 0)
  {
    printf("Failed to create server socket. Result: %d\n", server_socket);
    exit(1);
  }
  memset(&server_host, 0, sizeof(server_host));
  server_host.sin_family = AF_INET;
  server_host.sin_addr.s_addr = htonl(INADDR_ANY);
  server_host.sin_port = htons(PORT);
  result = bind(server_socket, (struct sockaddr*)&server_host, sizeof(server_host));
  if (result < 0)
  {
    printf("Failed to bind to socket %d. Result: %d\n", server_socket, result);
    close(server_socket);
    exit(1);
  }
  result = listen(server_socket, MAXPENDING);  // Last arg is our connection queue limit.
  if (result < 0)
  {
    printf("Failed to listen to socket %d. Result: %d\n", server_socket, result);
    close(server_socket);
    exit(1);
  }
  while (1)
  {
    unsigned int client_host_len = sizeof(client_host);
    // Block, waiting to accept a new connection:
    printf("Awaiting connection...\n");
    client_socket = accept(server_socket, (struct sockaddr*)&client_host, &client_host_len);
    if (client_socket < 0)
    {
      printf("Failed to accept client on socket %d. Result: %d\n", server_socket, client_socket);
      close(server_socket);
      exit(1);
    }
    RFB_HandleClient(client_socket);
  }
}
