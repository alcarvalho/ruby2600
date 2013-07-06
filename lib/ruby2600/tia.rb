module Ruby2600
  class TIA
    attr_accessor :cpu, :riot

    include Constants

    # A scanline "lasts" 228 "color clocks" (CLKs), of which 68
    # are the initial blank period, and each of the remai

    HORIZONTAL_BLANK_CLK_COUNT = 68
    TOTAL_SCANLINE_CLK_COUNT = 228

    # Maps which register/bit should be set for each playfield pixel

    PLAYFIELD_ORDER = [[PF0, 4], [PF0, 5], [PF0, 6], [PF0, 7],
                       [PF1, 7], [PF1, 6], [PF1, 5], [PF1, 4], [PF1, 3], [PF1, 2], [PF1, 1], [PF1, 0],
                       [PF2, 0], [PF2, 1], [PF2, 2], [PF2, 3], [PF2, 4], [PF2, 5], [PF2, 6], [PF2, 7]]

    def initialize
      @reg = Array.new(32) { rand(256) }
      @cpu_credits = 0
      @bl_counter = TIACounter.new
      @bl_counter.on_change { |value| bl_counter_increased(value) }
      @m0_counter = TIACounter.new
      @m0_counter.on_change { |value| m0_counter_increased(value) }
      @p0_counter = TIACounter.new
      @p0_counter.on_change { |value| p0_counter_increased(value) }
      @bl_pixels_to_draw = 0
      @m0_pixels_to_draw = 0
    end

    def [](position)

    end

    def []=(position, value)
      case position
      when RESBL
        @bl_counter.reset
      when RESM0
        @m0_counter.reset
      when RESP0
        @p0_counter.reset
      when HMOVE
        @bl_counter.move @HMBL
      else
        @reg[position] = value
      end
    end

    def scanline
      intialize_scanline
      wait_horizontal_blank
      draw_scanline
    end

    def frame
      buffer = []
      scanline while vertical_sync?
      buffer << scanline until vertical_sync?
      buffer
    end

    private

    def intialize_scanline
      reset_cpu_sync
      @scanline = Array.new(160, 0)
      @pixel = 0
    end

    def wait_horizontal_blank
      HORIZONTAL_BLANK_CLK_COUNT.times { |color_clock| sync_cpu_with color_clock }
    end

    def draw_scanline
      HORIZONTAL_BLANK_CLK_COUNT.upto TOTAL_SCANLINE_CLK_COUNT - 1 do |color_clock|
        sync_cpu_with color_clock
        unless vertical_blank?
          @scanline[@pixel] = p0_pixel || m0_pixel || bl_pixel || pf_pixel || bg_pixel
        end
        @pixel += 1
        @bl_counter.tick
        @m0_counter.tick
        @p0_counter.tick
      end
      @scanline
    end

    # The 2600 hardware wiring ensures that we have three color clocks
    # for each CPU clock, but "freezes" the CPU if WSYNC is set on TIA.
    #
    # To keep them in sync, we'll compute a "credit" for each color
    # clock, and "use" this credit when we have any of it

    def sync_cpu_with(color_clock)
      riot.pulse if color_clock % 3 == 0
      return if @reg[WSYNC]
      @cpu_credits += 1 if color_clock % 3 == 0
      @cpu_credits -= @cpu.step while @cpu_credits > 0
    end

    def reset_cpu_sync
      @cpu_credits = 0 if @reg[WSYNC]
      @reg[WSYNC] = nil
    end

    def vertical_blank?
      @reg[VBLANK] & 0b00000010 != 0
    end

    def vertical_sync?
      @reg[VSYNC] & 0b00000010 != 0
    end

    # Background

    def bg_pixel
      @reg[COLUBK]
    end

    # Playfield

    def pf_pixel
      pf_color if pf_bit_set?
    end

    def pf_color
      @reg[score_mode? ? COLUP0 + @pixel / 80 : COLUPF]
    end

    def pf_bit_set?
      pf_pixel = (@pixel / 4) % 20
      pf_pixel = 19 - pf_pixel if reflect_current_side?
      register, bit = PLAYFIELD_ORDER[pf_pixel]
      @reg[register][bit] == 1
    end

    def reflect_current_side?
      @reg[CTRLPF][0] == 1 && @pixel > 79
    end

    def score_mode?
      @reg[CTRLPF][1] == 1
    end

    # Players

    def p0_pixel
      return nil unless @p0_current_pixel
      pixel = @p0_current_pixel
      @p0_current_pixel -= 1
      @p0_current_pixel = nil if @p0_current_pixel < -1
      @reg[COLUP0] unless @reg[GRP0][pixel].zero?
    end

    def p0_counter_increased(value)
      # FIXME gotta shift this
      if value == 0
        @p0_current_pixel = 7
      elsif value == 1
        @p0_current_pixel = 3
      else
        @p0_current_pixel = nil
      end
    end

    # Missiles

    def m0_pixel
     return nil unless @reg[ENAM0][1]==1 && @m0_pixels_to_draw > 0
     @m0_pixels_to_draw -= 1
     @reg[COLUP0]
    end

    def m0_size
      2 ** (2 * @reg[NUSIZ0][5] + @reg[NUSIZ1][4])
    end

    def m0_counter_increased(value)
      if value == 0
        @ml_pixels_to_draw = 8
      end
    end

    # Ball

    def bl_pixel
      return nil unless @reg[ENABL][1]==1 && @bl_pixels_to_draw > 0
      @bl_pixels_to_draw -= 1
      @reg[COLUPF]
    end

    def bl_size
      2 ** (2 * @reg[CTRLPF][5] + @reg[CTRLPF][4])
    end

    def bl_counter_increased(value)
      if value == 0
        @bl_pixels_to_draw = [bl_size, 4].min
      elsif value == 1 && bl_size == 8
        @bl_pixels_to_draw = 4
      else
        @bl_pixels_to_draw = 0
      end
    end
  end
end


