#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <emacs-module.h>
#include <stdio.h>

int plugin_is_GPL_compatible;

@protocol GlassmacsApplicationReopen
- (void)newFrame:(id)sender;
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender
                    hasVisibleWindows:(BOOL)visible;
@end

static BOOL
glassmacs_application_should_handle_reopen(id delegate, SEL selector,
                                           NSApplication *application,
                                           BOOL has_visible_windows)
{
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

  if (!class_addMethod(object_getClass(delegate), selector,
                       (IMP) glassmacs_application_should_handle_reopen,
                       description.types)
      && ![delegate respondsToSelector:selector])
    {
      fputs("Glassmacs lifecycle bridge: could not install Cocoa reopen callback\n",
            stderr);
      return 1;
    }

  return 0;
}
