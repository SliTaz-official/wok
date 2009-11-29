#define int16 int16_t
#define uint16 uint16_t
#define int32 int32_t
#define uint32 uint32_t

#define CallNPN_GetURLNotifyProc(FUNC, ARG1, ARG2, ARG3, ARG4)   (*(FUNC))((ARG1), (ARG2), (ARG3), (ARG4))
#define	CallNPN_GetURLProc(FUNC, ARG1, ARG2, ARG3)   (*(FUNC))((ARG1), (ARG2), (ARG3))
#define CallNPN_PostURLNotifyProc(FUNC, ARG1, ARG2, ARG3, ARG4, ARG5, ARG6, ARG7)   (*(FUNC))((ARG1), (ARG2), (ARG3), (ARG4), (ARG5), (ARG6), (ARG7))
#define CallNPN_PostURLProc(FUNC, ARG1, ARG2, ARG3, ARG4, ARG5, ARG6)   (*(FUNC))((ARG1), (ARG2), (ARG3), (ARG4), (ARG5), (ARG6))
#define CallNPN_RequestReadProc(FUNC, stream, range)   (*(FUNC))((stream), (range))
#define CallNPN_NewStreamProc(FUNC, npp, type, window, stream)   (*(FUNC))((npp), (type), (window), (stream))
#define CallNPN_WriteProc(FUNC, npp, stream, len, buffer)   (*(FUNC))((npp), (stream), (len), (buffer))
#define CallNPN_DestroyStreamProc(FUNC, npp, stream, reason)   (*(FUNC))((npp), (stream), (reason))
#define CallNPN_StatusProc(FUNC, npp, msg)   (*(FUNC))((npp), (msg))
#define CallNPN_UserAgentProc(FUNC, ARG1)   (*(FUNC))((ARG1))
#define CallNPN_MemAllocProc(FUNC, ARG1)   (*(FUNC))((ARG1))
#define CallNPN_MemFreeProc(FUNC, ARG1)   (*(FUNC))((ARG1))
#define CallNPN_MemFlushProc(FUNC, ARG1)   (*(FUNC))((ARG1))
#define CallNPN_ReloadPluginsProc(FUNC, ARG1)   (*(FUNC))((ARG1))
#define CallNPN_GetValueProc(FUNC, ARG1, ARG2, ARG3)   (*(FUNC))((ARG1), (ARG2), (ARG3))
#define CallNPN_SetValueProc(FUNC, ARG1, ARG2, ARG3)   (*(FUNC))((ARG1), (ARG2), (ARG3))
#define CallNPN_InvalidateRectProc(FUNC, ARG1, ARG2)   (*(FUNC))((ARG1), (ARG2))
#define CallNPN_InvalidateRegionProc(FUNC, ARG1, ARG2)   (*(FUNC))((ARG1), (ARG2))
#define CallNPN_ForceRedrawProc(FUNC, ARG1)   (*(FUNC))((ARG1))

#include <stdlib.h>
#include <assert.h>
 
