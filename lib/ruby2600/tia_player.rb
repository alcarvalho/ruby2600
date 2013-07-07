module Ruby2600
  class TIAPlayer
    include Constants

    def initialize(tia_registers)
      @tia = tia_registers
      @counter = TIACounter.new
      @counter.on_change { |value| @grp_bit = -5 if value == 39 }
    end

    def pixel
      update_pixel_bit
      @counter.tick
      @tia[COLUP0] if @pixel_bit == 1
    end

    # FIXME might call reset?
    def strobe
      @counter.reset
    end

    # FIXME test; might call the counter one hmove?
    def hmove(value)
      @counter.move(value)
    end

    private

    def update_pixel_bit
      if @grp_bit
        @pixel_bit = @tia[GRP0][7 - @grp_bit] if (0..7).include?(@grp_bit)
        @grp_bit += 1 # we'll change this for REFPn
        @grp_bit = nil if @grp_bit > 7
      else
        @pixel_bit = nil
      end
    end
  end
end

