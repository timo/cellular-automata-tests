use NativeCall;
use SDL2::Raw;

constant W = 1024;
constant H = 786;

constant TILESIZE = 12;

constant COLS = W div TILESIZE;
constant ROWS = H div TILESIZE;

sub SDL_RenderFillRects(SDL_Renderer $renderer, Pointer[int32] $rects, int32 $count) returns int32 is native("SDL2") {*};

class RenderQueue {
    has @!blobs;
    has int @!colors;
    has int @!usage;
    has %!insertpoint;

    method enqueue($color, $rect) {
        my $slot = %!insertpoint{$color} //= +@!usage;
        if $slot >= +@!blobs {
            say "building a blob";
            @!blobs[$slot] = CArray[int32].new();
            @!usage[$slot] = 0;
        }
        @!colors[$slot] = $color;
        given @!blobs[$slot] {
            my int $inspos = @!usage[$slot] * 4;
            .[$inspos++] = $rect.x;
            .[$inspos++] = $rect.y;
            .[$inspos++] = $rect.w;
            .[$inspos++] = $rect.h;
        }
        @!usage[$slot]++;
    }

    method render($render) {
        for @!colors.kv -> $slot, $color {
            SDL_SetRenderDrawColor($render, $color, $color, $color, 255);
            SDL_RenderFillRects($render, nativecast(Pointer[int32], @!blobs[$slot]), @!usage[$slot]);
        }

        %!insertpoint = ().hash;
        @!colors = Empty;
        @!usage = Empty;
    }
}

my $window = SDL_CreateWindow("Snake",
        SDL_WINDOWPOS_CENTERED_MASK, SDL_WINDOWPOS_CENTERED_MASK,
        W, H,
        OPENGL);
my $render = SDL_CreateRenderer($window, -1, ACCELERATED +| PRESENTVSYNC);

my $event = SDL_Event.new;

my $colrange := ^256;
my $probability := ^4;

srand(1234);

# having a "double buffer" is a bit better than keeping a list of coordinates
# to update around and going through the grid twice.
my @grid   = [(^2).roll(COLS + 2)] xx (ROWS + 2);
@grid[0    ] = [Inf xx (COLS + 2)];
@grid[* - 1] = [Inf xx (COLS + 2)];
@grid[*;  0] = Inf xx *;
@grid[*;*-1] = Inf xx *;
my @o'grid = @grid.map: *.clone;

my $cols_list := 1 .. (COLS);
my $rows_list := 1 .. (ROWS);

my SDL_Rect $tgt .= new(0, 0, TILESIZE, TILESIZE);

my int $frame = 0;

my RenderQueue $rect_queue .= new;

main: loop {
    while SDL_PollEvent($event) {
        #my $casted_event = SDL_CastEvent($event);
        given $event {
            when *.type == QUIT {
                last main;
            }
        }
    }

    loop (my int $x = 1; $x <= COLS; $x = $x + 1) {
    #for $cols_list -> $x {
        $tgt.x = $x * TILESIZE - TILESIZE;
        my int $px = $x - 1;
        my int $nx = $x + 1;
        loop (my int $y = 1; $y <= ROWS; $y = $y + 1) {
        #for $rows_list -> $y {
            my int $py = $y - 1;
            my int $ny = $y + 1;
            my int $b = @grid[$y][$x];

            if 10.rand <= 1 {
                my @pr := @grid[$py];
                my @cr := @grid[$y ];
                my @nr := @grid[$ny];
                my @neighbours = @pr[$px], @pr[$x], @pr[$nx]
                                ,@cr[$px],          @cr[$nx]
                                ,@nr[$px], @nr[$x], @nr[$nx];
                if @neighbours.min < $b {
                    @o'grid[$y][$x] = $b;
                } else {
                    @o'grid[$y][$x] = $b + 1;
                }
            } else {
                @o'grid[$y][$x] = $b;
            }

            $tgt.y = $y * TILESIZE - TILESIZE;
            my int $col = ($b * 75) % 225 + 25;
            $rect_queue.enqueue($col, $tgt);
        }
    }

    $rect_queue.render($render);

    my @tmp := @grid;
    @grid := @o'grid;
    @o'grid := @tmp;

    SDL_RenderPresent($render);

    $frame = $frame + 1;
    if $frame == 500 { last }
    if $frame == 1 { say now - BEGIN now }
}
