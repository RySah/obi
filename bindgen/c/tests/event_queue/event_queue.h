
#ifndef EVENT_QUEUE_H
#define EVENT_QUEUE_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>
#include <stdint.h>

/* ===========================
   Versioning
   =========================== */

#define EQ_VERSION_MAJOR 1
#define EQ_VERSION_MINOR 0
#define EQ_VERSION_PATCH 0

/* ===========================
   Error codes
   =========================== */

enum Simple_Enum_Lol {
    IDK1,
    IDK2,
    IDK3
};

typedef enum EQ_Result {
    EQ_OK = 0,
    EQ_ERR_INVALID_ARGUMENT = -1,
    EQ_ERR_OUT_OF_MEMORY    = -2,
    EQ_ERR_QUEUE_FULL       = -3,
    EQ_ERR_QUEUE_EMPTY      = -4
} EQ_Result;

/* ===========================
   Event types
   =========================== */

typedef enum EQ_EventType {
    EQ_EVENT_NONE = 0,
    EQ_EVENT_CONNECT,
    EQ_EVENT_DISCONNECT,
    EQ_EVENT_MESSAGE,
    EQ_EVENT_TIMEOUT
} EQ_EventType;

typedef struct EQ_EventMessage {
    const char* data;
    size_t length;
    uint8_t keys[8];
} EQ_EventMessage;

typedef struct EQ_UnknownEventMessage {
    void* data;
    size_t length;
} EQ_UnknownEventMessage;

/* ===========================
   Opaque queue handle
   =========================== */

typedef struct EQ_Queue EQ_Queue;

typedef int (*EQ_Callback_T)(char *cmd_name, EQ_Queue *queue);

/* ===========================
    Event payload
    =========================== */
typedef struct EQ_Event
{
    int (**cb)(int, int);
    EQ_EventType type;
    uint64_t     timestamp_ns;
    union {
        struct {
            uint32_t client_id;
        } connect;

        struct {
            uint32_t client_id;
            uint32_t reason;
        } disconnect;

        struct {
            uint32_t client_id;
            const void *data;
            size_t data_size;
        } message;
    } payload;
} EQ_Event;

typedef struct EQ_OptionSet {
    uint8_t read : 1;
    uint8_t write : 5;
    uint16_t read_write_range;
    uint32_t try_truncate : 3;
    uint32_t full_truncate : 12;
} EQ_Options;

/* ===========================
   API functions
   =========================== */

/* Create a queue capable of holding `capacity` events */
EQ_Queue *eq_queue_create(size_t capacity, int(*cb)(int, int));

/* Destroy a queue created with eq_queue_create */
void eq_queue_destroy(EQ_Queue *queue, char some_bytes[52]);

/* Push an event into the queue */
EQ_Result eq_queue_push(EQ_Queue *queue, const EQ_Event *event);

/* Pop the oldest event from the queue */
EQ_Result eq_queue_pop(EQ_Queue *queue, EQ_Event *out_event);

/* Get the current number of events */
size_t eq_queue_size(const EQ_Queue *queue);

/* Get the maximum capacity */
size_t eq_queue_capacity(const EQ_Queue *queue);

#ifdef __cplusplus
}
#endif

#endif /* EVENT_QUEUE_H */

