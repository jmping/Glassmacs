#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <emacs-module.h>
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>

int plugin_is_GPL_compatible;

@protocol GlassmacsEmacsView
- (id)menuDown:(id)sender;
- (void)keyDown:(NSEvent *)event;
@end

@protocol GlassmacsApplicationReopen
- (void)newFrame:(id)sender;
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender
                    hasVisibleWindows:(BOOL)visible;
@end

/* Opt-in trace for the acceptance tests: when GLASSMACS_LIFECYCLE_TRACE
   names a file, append a line to it.  Shows whether the callbacks were
   installed and whether macOS delivered a reopen (a Dock click).  */
static void
glassmacs_trace (const char *format, ...)
{
  const char *path = getenv ("GLASSMACS_LIFECYCLE_TRACE");
  if (path == NULL || *path == '\0')
    return;
  FILE *file = fopen (path, "a");
  if (file == NULL)
    return;
  va_list arguments;
  va_start (arguments, format);
  fputs ("Glassmacs lifecycle: ", file);
  vfprintf (file, format, arguments);
  fputc ('\n', file);
  va_end (arguments);
  fclose (file);
}

static BOOL
glassmacs_application_should_handle_reopen(id delegate, SEL selector,
                                           NSApplication *application,
                                           BOOL has_visible_windows)
{
  glassmacs_trace ("reopen, visible windows: %d, delegate has newFrame: %d",
                   (int) has_visible_windows,
                   (int) [delegate respondsToSelector:@selector(newFrame:)]);
  if (!has_visible_windows)
    {
      SEL new_frame = @selector(newFrame:);
      if ([delegate respondsToSelector:new_frame])
        {
          [(id<GlassmacsApplicationReopen>) delegate newFrame:application];
          return NO;
        }
    }

  return YES;
}

/* Emacs's menu items (action menuDown:) and Command-key equivalents are
   handled only by an EmacsView, which AppKit reaches through the key
   window.  After the last window is hidden there is no key window, so
   those events are dropped.  Route them to the hidden frame's EmacsView,
   which is still the selected Emacs frame.  */
static id<GlassmacsEmacsView>
glassmacs_hidden_emacs_view(void)
{
  id<GlassmacsEmacsView> view = nil;
  for (NSWindow *window in [NSApp windows])
    {
      if (window.isVisible || window.isMiniaturized
          || ![NSStringFromClass([window class]) hasSuffix:@"EmacsWindow"])
        continue;
      id candidate = window.delegate;
      if ([candidate respondsToSelector:@selector(menuDown:)]
          && [candidate respondsToSelector:@selector(keyDown:)])
        view = candidate;
    }
  return view;
}

static BOOL
glassmacs_no_window_can_receive_events(void)
{
  return NSApp.keyWindow == nil && NSApp.mainWindow == nil;
}

static id
glassmacs_menu_down(id delegate, SEL selector, id sender)
{
  id<GlassmacsEmacsView> view = glassmacs_no_window_can_receive_events()
    ? glassmacs_hidden_emacs_view() : nil;
  if (view != nil)
    return [view menuDown:sender];
  return delegate;
}

static void
glassmacs_install_windowless_key_monitor(void)
{
  [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
    handler:^NSEvent *(NSEvent *event) {
      if (!glassmacs_no_window_can_receive_events() || event.window != nil)
        return event;
      /* Leave standard app-level Command shortcuts to the main menu. */
      if (event.modifierFlags & NSEventModifierFlagCommand)
        {
          NSString *key = event.charactersIgnoringModifiers.lowercaseString;
          if ([@"qwhm," containsString:key] && key.length == 1)
            return event;
        }
      id<GlassmacsEmacsView> view = glassmacs_hidden_emacs_view();
      if (view == nil)
        return event;
      [view keyDown:event];
      return nil;
    }];
}

int
emacs_module_init(struct emacs_runtime *runtime)
{
  (void) runtime;

  NSApplication *application = NSApp;
  id delegate = application.delegate;
  if (delegate == nil)
    {
      fputs("Glassmacs lifecycle bridge: Cocoa application delegate is missing\n",
            stderr);
      return 1;
    }

  NSString *icon_path =
    [[NSBundle mainBundle] pathForResource:@"Glassmacs" ofType:@"icns"];
  NSImage *icon = icon_path != nil
    ? [[NSImage alloc] initWithContentsOfFile:icon_path]
    : nil;
  if (icon == nil)
    {
      fputs("Glassmacs lifecycle bridge: bundled Glassmacs.icns is missing or unreadable\n",
            stderr);
      return 1;
    }

  SEL selector =
    @selector(applicationShouldHandleReopen:hasVisibleWindows:);
  struct objc_method_description description =
    protocol_getMethodDescription(@protocol(GlassmacsApplicationReopen),
                                  selector, YES, YES);
  if (description.types == NULL)
    {
      fputs("Glassmacs lifecycle bridge: invalid reopen callback signature\n",
            stderr);
      return 1;
    }

  BOOL added = class_addMethod(object_getClass(delegate), selector,
                               (IMP) glassmacs_application_should_handle_reopen,
                               description.types);
  glassmacs_trace ("installed; delegate %s, reopen callback added: %d",
                   class_getName(object_getClass(delegate)), (int) added);
  if (!added && ![delegate respondsToSelector:selector])
    {
      fputs("Glassmacs lifecycle bridge: could not install Cocoa reopen callback\n",
            stderr);
      return 1;
    }

  SEL menu_down = @selector(menuDown:);
  if (![delegate respondsToSelector:menu_down])
    class_addMethod(object_getClass(delegate), menu_down,
                    (IMP) glassmacs_menu_down, "@@:@");
  glassmacs_install_windowless_key_monitor();

  [application setApplicationIconImage:icon];
  return 0;
}
