module Ruby2600
  class TIAPlayer
    def initialize(tia)
      @tia = tia
      @counter = TIACounter.new
      @bit_queue = 0
      @counter.on_change { |value| @bit_queue = reverse(@tia[GRP0]) << 1 if value == 0 }
    end

    def pixel
      @counter.tick
      fetch_pixel
    end

    def strobe
      # Counter should reset 5 CLKs (pixels) from now
      @counter.value = 39
    end

    def fetch_pixel
      puts "Q: #{@bit_queue}"
      bit = @bit_queue[0]
      @bit_queue >>= 1
      @tia[COLUP0] if bit == 1
    end

    private

    def reverse(byte)
      (0..7).reduce(0) { |sum, bit| sum + byte[bit] * 2 ** (7 - bit) }
    end
  end
end

