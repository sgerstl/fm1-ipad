#ifndef LUPE_CANDROID_H
#define LUPE_CANDROID_H
#ifdef __ANDROID__
#include <jni.h>
#include <android/looper.h>
#include <android/log.h>
#include <sys/eventfd.h>
#include <sys/types.h>
#include <unistd.h>
#include <pthread.h>

static inline int lupe_log(int prio, const char *msg) { return __android_log_write(prio, "Lupe", msg); }
#endif
#endif
