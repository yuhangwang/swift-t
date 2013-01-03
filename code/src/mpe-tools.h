
/*
 * mpe-tools.h
 *
 *  Created on: Aug 28, 2012
 *      Author: wozniak
 *
 *  Tools to simplify use of MPE
 */

#ifndef MPE_TOOLS_H
#define MPE_TOOLS_H

#ifdef ENABLE_MPE

#include <stdio.h>

#include <mpe.h>

/**
   Declare event pairs
   Note: these names must be conventional for use with our macros
   The convention is: xlb_mpe_[svr|dmn|wkr]?_<OP>_[start|end]
*/

#define extern_declare_pair(component, function) \
  extern int xlb_mpe_##component##_##function##_start, \
  xlb_mpe_##component##_##function##_end;

// Events for servers and workers:
extern_declare_pair(all, init);
extern_declare_pair(all, finalize);

// Server handler events:
// The server is servicing some request
extern_declare_pair(svr, busy);
// Task operations:
extern_declare_pair(svr, put);
extern_declare_pair(svr, get);
extern_declare_pair(svr, steal);
extern_declare_pair(svr, shutdown);
// Data module:
extern_declare_pair(svr, create);
extern_declare_pair(svr, subscribe);
extern_declare_pair(svr, store);
extern_declare_pair(svr, retrieve);

// Server daemon events (steal, shutdown):
extern_declare_pair(dmn, steal);
extern_declare_pair(dmn, shutdown);

// Client calls:
// Task operations:
extern_declare_pair(wkr, put);
extern_declare_pair(wkr, get);
// Data module:
extern_declare_pair(wkr, unique);
extern_declare_pair(wkr, create);
extern_declare_pair(wkr, subscribe);
extern_declare_pair(wkr, store);
extern_declare_pair(wkr, retrieve);
extern_declare_pair(wkr, subscribe);
extern_declare_pair(wkr, close);
extern_declare_pair(wkr, insert);
extern_declare_pair(wkr, lookup);

// Info event:
extern int xlb_mpe_svr_info;

void xlb_mpe_setup(void);

/** Do x only if ENABLE_MPE is set */
#define MPE(x) x;

#define MPE_INFO(e,fmt,args...) { \
  char t[32];                \
  snprintf(t, 32, fmt, ## args);      \
  printf("INFO: %s\n", t);\
  MPE_Log_event(e,0,t);}

#else

/** MPE is not enabled - noop */
#define MPE(x)
/** MPE is not enabled - noop */
#define MPE_INFO(e,msg...)

#endif

#define MPE_LOG(e) MPE(MPE_Log_bare_event(e));

#endif
