module Ruby2600
  # Movable objects are implemented internally on TIA using counters that go
  # from 0 to 39, but only increment after 4 color clocks (to match the 160
  # pixels of a scanline)
  # See http://www.atarihq.com/danb/files/TIA_HW_Notes.txt

  #FIXME too many magic numbers here (160, 4); review test coverage due to hmove spike
  class TIACounter
    def initialize
      @internal_value = rand(160)
    end

    def reset
      @internal_value = 35 * 4
    end

    def value
      @internal_value / 4
    end

    def value=(x)
      @internal_value = x * 4
    end

    def tick
      old_value = value
      internal_value_add 1
      @on_change.call(value) if @on_change && value != old_value
    end

    def move(tia_motion_value)
      return unless tia_motion_value # FIXME should we care here?
      internal_value_add nibble_to_decimal(tia_motion_value)
    end

    def on_change(&block)
      @on_change = block
    end

    private

    def internal_value_add(value)
      @internal_value += value
      @internal_value -= 160 while @internal_value > 159
      @internal_value += 160 while @internal_value < 0
    end

    def nibble_to_decimal(signed_nibble)
      absolute = signed_nibble & 0b0111
      signal   = signed_nibble[3] * 2 - 1
      absolute * signal
    end
  end
end


