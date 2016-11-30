/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import <Foundation/NSZone.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSHashTable.h>
#import <Foundation/NSRaise.h>
#import <Foundation/NSZombieObject.h>
#import <Foundation/NSDebug.h>
#import <objc/objc_arc.h>
#include <string.h>
#ifdef WIN32
#include <windows.h>
#else
#include <unistd.h>
#endif

// NSZone functions implemented in platform subproject

void NSIncrementExtraRefCount(id object) {
    object_incrementExternalRefCount(object);
}

BOOL NSDecrementExtraRefCountWasZero(id object) {
    return object_decrementExternalRefCount(object);
}

NSUInteger NSExtraRefCount(id object) {
    return object_externalRefCount(object);
}

BOOL NSShouldRetainWithZone(id object,NSZone *zone) {
   return (zone==NULL || zone==NSDefaultMallocZone() || zone==[object zone])?YES:NO;
}

static void (*__NSAllocateObjectHook)(id object) = 0;

void NSSetAllocateObjectHook(void (*hook)(id object))
{
    __NSAllocateObjectHook = hook;
}


id NSAllocateObject(Class class, NSUInteger extraBytes, NSZone *zone)
{
    id result;

    if (zone == NULL) {
        zone = NSDefaultMallocZone();
    }

    result = NSZoneCalloc(zone, 1, class_getInstanceSize(class) + extraBytes);

    if (result) {
#if defined(GCC_RUNTIME_3)
        object_setClass(result, class);
        // TODO As of gcc 4.6.2 the GCC runtime does not have support for C++ constructor calling.
#elif defined(APPLE_RUNTIME_4)
        objc_constructInstance(class, result);
#else
    object_setClass(result, class);

        if (!object_cxxConstruct(result, object_getClass(result))) {
            NSZoneFree(zone, result);
            result = nil;
        }
#endif

        if (__NSAllocateObjectHook) {
            __NSAllocateObjectHook(result);
        }
    }
    
    return result;
}


void NSDeallocateObject(id object)
{
#if defined(GCC_RUNTIME_3)
    // TODO As of gcc 4.6.2 the GCC runtime does not have support for C++ destructor calling.
#elif defined(APPLE_RUNTIME_4)
    objc_destructInstance(object);
#else
    object_cxxDestruct(object, object_getClass(object));
#endif

#if !defined(APPLE_RUNTIME_4)
    //delete associations
    objc_removeAssociatedObjects(object);
#endif
    
    if (NSZombieEnabled) {
        NSRegisterZombie(object);
    } else {
        NSZone *zone = NULL;

        if (zone == NULL) {
            zone = NSDefaultMallocZone();
        }

#if !defined(GCC_RUNTIME_3) && !defined(APPLE_RUNTIME_4)
        object_setClass(object, (Class)NULL);
#endif

        NSZoneFree(zone, object);
    }
}


id NSCopyObject(id object, NSUInteger extraBytes, NSZone *zone)
{
    if (object == nil) {
        return nil;
    }

    id result = NSAllocateObject(object_getClass(object), extraBytes, zone);

    if (result) {
        memcpy(result, object, class_getInstanceSize(object_getClass(object)) + extraBytes);
    }
    
    return result;
}
