module Ruby2600
  class TIA
    attr_accessor :cpu, :riot
    attr_reader :reg

    include Constants

    # A scanline "lasts" 228 "color clocks" (CLKs), of which 68
    # are the horizontal blank period, and 160 are visible pixels

    HORIZONTAL_BLANK_CLK_COUNT = 68
    VISIBLE_CLK_COUNT = 160

    def initialize
      # Real 2600 starts with random values (and Stella comments warn
      # about games that crash if we start with all zeros)
      @reg = Array.new(64) { rand(256) }

      @p0 = Player.new(self, 0)
      @p1 = Player.new(self, 1)
      @m0 = Missile.new(self, 0)
      @m1 = Missile.new(self, 1)
      @bl = Ball.new(self)
      @pf = Playfield.new(self)
      @movable_graphics = [@p0, @p1, @m0, @m1, @bl]

      @port_level = Array.new(6, false)
      @latch_level = Array.new(6, true)
    end

    def frame
      buffer = []
      scanline while vertical_sync?                 # VSync
      scanline while vertical_blank?                # VBlank
      buffer << scanline until vertical_blank?      # Picture
      scanline until vertical_sync?                 # Overscan
      buffer
    end

    def scanline
      intialize_scanline
      wait_horizontal_blank
      draw_scanline
    end

    def set_port_level(number, level)
      @port_level[number] = (level == :high)
      @latch_level[number] = false if level == :low
    end

    # Accessors for games (other classes should use :reg to avoid side effects)

    def [](position)
      case position
      when CXM0P..CXPPMM then @reg[position]
      when INPT0..INPT5  then value_for_port(position - INPT0)
      end
    end

    def []=(position, value)
      case position
      when RESP0
        @p0.counter.strobe
      when RESP1
        @p1.counter.strobe
      when RESM0
        @m0.counter.strobe
      when RESM1
        @m1.counter.strobe
      when RESBL
        @bl.counter.strobe
      when RESMP0
        @m0.counter.reset_to @p0.counter
      when RESMP1
        @m1.counter.reset_to @p1.counter
      when HMOVE
        @late_reset_hblank = true
        @movable_graphics.each &:start_hmove
      when HMCLR
        @reg[HMP0] = @reg[HMP1] = @reg[HMM0] = @reg[HMM1] = @reg[HMBL] = 0
      when CXCLR
        @reg[CXM0P] = @reg[CXM1P] = @reg[CXP0FB] = @reg[CXP1FB] = @reg[CXM0FB] = @reg[CXM1FB] = @reg[CXBLPF] = @reg[CXPPMM] = 0
      when WSYNC
        @cpu.halted = true
      when VSYNC..VDELBL
        @reg[position] = value
      end
      @p0.old_value = @reg[GRP0]  if position == GRP1
      @bl.old_value = @reg[ENABL] if position == GRP1
      @p1.old_value = @reg[GRP1]  if position == GRP0
      @latch_level.fill(true)     if position == VBLANK && value[6] == 1
    end

    private

    def intialize_scanline
      @cpu.halted = false
      @late_reset_hblank = false
    end

    def wait_horizontal_blank
      HORIZONTAL_BLANK_CLK_COUNT.times { |color_clock| sync_2600_with color_clock }
    end

    def draw_scanline
      scanline = Array.new(160, 0)
      VISIBLE_CLK_COUNT.times do |pixel|
        extended_hblank = @late_reset_hblank && pixel < 8

        fetch_pixels extended_hblank
        update_collision_flags

        scanline[pixel] = topmost_pixel unless vertical_blank? || extended_hblank

        sync_2600_with pixel + HORIZONTAL_BLANK_CLK_COUNT
      end
      scanline
    end

    def fetch_pixels(with_tick)
      @pf_pixel = @pf.pixel
      @bk_pixel = @reg[COLUBK]
      @p0_pixel = @p0.pixel with_tick
      @p1_pixel = @p1.pixel with_tick
      @m0_pixel = @m0.pixel with_tick
      @m1_pixel = @m1.pixel with_tick
      @bl_pixel = @bl.pixel with_tick
    end

    def topmost_pixel
      if @reg[CTRLPF][2].zero?
        @p0_pixel || @m0_pixel || @p1_pixel || @m1_pixel || @bl_pixel || @pf_pixel || @bk_pixel
      else
        @pf_pixel || @bl_pixel || @p0_pixel || @m0_pixel || @p1_pixel || @m1_pixel || @bk_pixel
      end
    end

    BIT_6 = 0b01000000
    BIT_7 = 0b10000000

    def update_collision_flags
      @reg[CXM0P]  |= BIT_6 if @m0_pixel && @p0_pixel
      @reg[CXM0P]  |= BIT_7 if @m0_pixel && @p1_pixel
      @reg[CXM1P]  |= BIT_6 if @m1_pixel && @p1_pixel
      @reg[CXM1P]  |= BIT_7 if @m1_pixel && @p0_pixel
      @reg[CXP0FB] |= BIT_6 if @p0_pixel && @bl_pixel
      @reg[CXP0FB] |= BIT_7 if @p0_pixel && @pf_pixel
      @reg[CXP1FB] |= BIT_6 if @p1_pixel && @bl_pixel
      @reg[CXP1FB] |= BIT_7 if @p1_pixel && @pf_pixel
      @reg[CXM0FB] |= BIT_6 if @m0_pixel && @bl_pixel
      @reg[CXM0FB] |= BIT_7 if @m0_pixel && @pf_pixel
      @reg[CXM1FB] |= BIT_6 if @m1_pixel && @bl_pixel
      @reg[CXM1FB] |= BIT_7 if @m1_pixel && @pf_pixel
      # c-c-c-combo breaker: bit 6 of CXLBPF is unused
      @reg[CXBLPF] |= BIT_7 if @bl_pixel && @pf_pixel
      @reg[CXPPMM] |= BIT_6 if @m0_pixel && @m1_pixel
      @reg[CXPPMM] |= BIT_7 if @p0_pixel && @p1_pixel
    end

    # All Atari chips use the same crystal for their clocks (with RIOT and
    # CPU running at 1/3 of TIA speed).

    # Since the emulator's "main loop" is based on TIA#scanline, we'll "tick"
    # the other chips here (and also apply the horizontal motion on movable
    # objects, just like the hardware does)

    def sync_2600_with(color_clock)
      riot.tick if color_clock % 3 == 0
      @movable_graphics.each &:apply_hmove
      cpu.tick if color_clock % 3 == 2
    end

    def value_for_port(number)
      return 0x00 if grounded_port?(number)
      level =   @port_level[number]
      level &&= @latch_level[number] if latched_port?(number)
      level ? 0x80 : 0x00
    end

    def grounded_port?(number)
      @reg[VBLANK][7] == 1 && number <= 3
    end

    def latched_port?(number)
      @reg[VBLANK][6] == 1 && number >= 4
    end

    def vertical_blank?
      @reg[VBLANK][1] != 0
    end

    def vertical_sync?
      @reg[VSYNC][1] != 0
    end
  end
end


