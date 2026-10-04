#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "Canvas.h"

static int       g_w = 0, g_h = 0;
static uint32_t *g_px = NULL;

static int g_fill_r = 0, g_fill_g = 0, g_fill_b = 0, g_fill_on = 1;

typedef struct { int x, y, w, h, r, g, b; } BoxFrame;
static BoxFrame g_box_stack[32];
static int      g_box_sp = 0;

static inline uint32_t pack(int r, int g, int b) {
    return (uint32_t)r | ((uint32_t)g << 8) | ((uint32_t)b << 16) | 0xFF000000u;
}

void size(int w, int h) {
    if (w <= 0 || h <= 0) return;
    if (w == g_w && h == g_h) return;
    free(g_px);
    g_w = w; g_h = h;
    g_px = (uint32_t *)calloc((size_t)w * h, sizeof(uint32_t));
}

void background(int r, int g, int b) {
    if (!g_px) return;
    uint32_t v = pack(r, g, b);
    size_t n = (size_t)g_w * g_h;
    for (size_t i = 0; i < n; i++) g_px[i] = v;
}

void fill(int r, int g, int b) { g_fill_r = r; g_fill_g = g; g_fill_b = b; g_fill_on = 1; }
void no_fill(void) { g_fill_on = 0; }

static inline void put_px(int x, int y, uint32_t v) {
    if (x < 0 || y < 0 || x >= g_w || y >= g_h) return;
    g_px[(size_t)y * g_w + x] = v;
}

void circle(int cx, int cy, int r) {
    if (!g_px || !g_fill_on || r <= 0) return;
    uint32_t v = pack(g_fill_r, g_fill_g, g_fill_b);
    int x = r, y = 0, err = 1 - r;
    while (x >= y) {
        put_px(cx + x, cy + y, v); put_px(cx + y, cy + x, v);
        put_px(cx - y, cy + x, v); put_px(cx - x, cy + y, v);
        put_px(cx - x, cy - y, v); put_px(cx - y, cy - x, v);
        put_px(cx + y, cy - x, v); put_px(cx + x, cy - y, v);
        y++;
        if (err < 0) err += 2 * y + 1;
        else { x--; err += 2 * (y - x) + 1; }
    }
}

void line(int x0, int y0, int x1, int y1) {
    if (!g_px || !g_fill_on) return;
    uint32_t v = pack(g_fill_r, g_fill_g, g_fill_b);
    int dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
    int dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
    int err = dx + dy;
    for (;;) {
        put_px(x0, y0, v);
        if (x0 == x1 && y0 == y1) break;
        int e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
    }
}

void canvas_box_begin(int x, int y, int w, int h) {
    if (g_box_sp >= 32) return;
    BoxFrame *f = &g_box_stack[g_box_sp++];
    f->x = x; f->y = y; f->w = w; f->h = h;
    f->r = g_fill_r; f->g = g_fill_g; f->b = g_fill_b;
}

void canvas_box_end(void) {
    if (g_box_sp <= 0) return;
    BoxFrame *f = &g_box_stack[--g_box_sp];
    if (g_fill_on && g_px) {
        uint32_t v = pack(g_fill_r, g_fill_g, g_fill_b);
        for (int j = 0; j < f->h; j++) {
            int yy = f->y + j;
            if (yy < 0 || yy >= g_h) continue;
            for (int i = 0; i < f->w; i++) {
                int xx = f->x + i;
                if (xx < 0 || xx >= g_w) continue;
                g_px[(size_t)yy * g_w + xx] = v;
            }
        }
    }
    g_fill_r = f->r; g_fill_g = f->g; g_fill_b = f->b;
}

@interface CanvasView : UIView
@property (nonatomic, copy) void (^onDraw)(void);
- (void)start;
- (void)stop;
@end

@implementation CanvasView {
    CALayer       *_imgLayer;
    CADisplayLink *_link;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.blackColor;
        self.layer.magnificationFilter = @"nearest";
        self.layer.minificationFilter  = @"nearest";

        _imgLayer = [CALayer layer];
        _imgLayer.frame = self.bounds;
        _imgLayer.magnificationFilter = @"nearest";
        _imgLayer.minificationFilter  = @"nearest";
        _imgLayer.contentsGravity     = kCAGravityResize;
        [self.layer addSublayer:_imgLayer];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _imgLayer.frame = self.bounds;
}

- (void)render {
    if (!g_px || g_w <= 0 || g_h <= 0) return;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(
        (void *)g_px, g_w, g_h,
        8, g_w * 4, cs,
        kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
    if (ctx) {
        CGImageRef img = CGBitmapContextCreateImage(ctx);
        CGContextRelease(ctx);
        if (img) {
            _imgLayer.contents = (__bridge id)img;
            CGImageRelease(img);
        }
    }
    CGColorSpaceRelease(cs);
}

- (void)start {
    if (_link) return;
    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(_tick)];
    [_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSDefaultRunLoopMode];
}
- (void)stop { [_link invalidate]; _link = nil; }
- (void)_tick { if (self.onDraw) self.onDraw(); [self render]; }
- (void)dealloc { [self stop]; }

@end

@interface CanvasAppViewController : UIViewController
@property (nonatomic, strong) CanvasView *canvas;
@end

@implementation CanvasAppViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.canvas = [[CanvasView alloc] initWithFrame:self.view.bounds];
    self.canvas.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.canvas];

    self.canvas.onDraw = ^{ draw(); };
    [self.canvas start];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    static dispatch_once_t once;
    dispatch_once(&once, ^{ setup(); });
}

@end

@interface CanvasAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation CanvasAppDelegate
- (BOOL)application:(UIApplication *)app
        didFinishLaunchingWithOptions:(NSDictionary *)opts {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[CanvasAppViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil,
                                 NSStringFromClass([CanvasAppDelegate class]));
    }
}