#import <React/RCTBridgeModule.h>
#import <React/RCTComponentViewFactory.h>
#import <React/RCTParagraphComponentView.h>
#import <React/RCTViewComponentView.h>

#include <react/renderer/components/text/BaseParagraphComponentDescriptor.h>
#include <react/renderer/components/text/ParagraphShadowNode.h>
#include <react/renderer/components/view/ViewShadowNode.h>
#include <react/renderer/core/ConcreteComponentDescriptor.h>

#include <atomic>
#include <cstdio>
#include <unistd.h>

using namespace facebook::react;

static std::atomic<int> libraryViewAdoptions{0};
static std::atomic<int> libraryParagraphAdoptions{0};

// The library's own descriptor for View: React Native's, counting every shadow node it adopts.
class LibraryViewComponentDescriptor final : public ConcreteComponentDescriptor<ViewShadowNode> {
 public:
  using ConcreteComponentDescriptor::ConcreteComponentDescriptor;

 protected:
  void adopt(ShadowNode &shadowNode) const override
  {
    ConcreteComponentDescriptor::adopt(shadowNode);
    libraryViewAdoptions += 1;
  }
};

// The library's own descriptor for Paragraph (<Text>): React Native's, counting every shadow node it adopts.
class LibraryParagraphComponentDescriptor final : public BaseParagraphComponentDescriptor<ParagraphShadowNode> {
 public:
  using BaseParagraphComponentDescriptor::BaseParagraphComponentDescriptor;

 protected:
  void adopt(ShadowNode &shadowNode) const override
  {
    BaseParagraphComponentDescriptor::adopt(shadowNode);
    libraryParagraphAdoptions += 1;
  }
};

static void printLine(NSString *line)
{
  printf("%s\n", line.UTF8String);
  fflush(stdout);
}

@interface LibraryViewComponentView : RCTViewComponentView
@end

@implementation LibraryViewComponentView

+ (void)load
{
  [RCTComponentViewFactory.currentComponentViewFactory registerComponentViewClass:self];
  printLine(@"library: registered LibraryViewComponentView, whose descriptor is LibraryViewComponentDescriptor, for View");
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<LibraryViewComponentDescriptor>();
}

@end

@interface LibraryParagraphComponentView : RCTParagraphComponentView
@end

@implementation LibraryParagraphComponentView

+ (void)load
{
  [RCTComponentViewFactory.currentComponentViewFactory registerComponentViewClass:self];
  printLine(
      @"library: registered LibraryParagraphComponentView, whose descriptor is LibraryParagraphComponentDescriptor, for Paragraph");
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<LibraryParagraphComponentDescriptor>();
}

@end

@interface LibraryDescriptorsProbe : NSObject <RCTBridgeModule>
@end

@implementation LibraryDescriptorsProbe

RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

// Called once the app's first render is mounted. With --exit-after-report among the launch arguments the app ends
// here, so a script that launched it reads the report and the app's exit.
RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(report)
{
  NSString *report = [NSString
      stringWithFormat:@"library: LibraryViewComponentDescriptor adopted %d shadow nodes\nlibrary: LibraryParagraphComponentDescriptor adopted %d shadow nodes",
                       libraryViewAdoptions.load(),
                       libraryParagraphAdoptions.load()];
  printLine(report);
  if ([NSProcessInfo.processInfo.arguments containsObject:@"--exit-after-report"]) {
    _exit(0);
  }
  return report;
}

@end
