require 'spec_helper'
include Ruby2600::Constants

describe Ruby2600::TIA do

  subject(:tia) do
    tia = Ruby2600::TIA.new
    tia.cpu = mock('cpu', :tick => nil, :halted= => nil)
    tia.riot = mock('riot', :tick => nil)
    tia
  end

  def clear_tia_registers
    0x3F.downto(0) { |reg| tia[reg] = 0 }
  end

  describe '#initialize' do
    it 'should initialize with random values on registers' do
      registers1 = Ruby2600::TIA.new.instance_variable_get(:@reg)
      registers2 = tia.instance_variable_get(:@reg)

      registers1.should_not == registers2
    end

    it "should initialize with valid (byte-size) values on registers" do
      tia.instance_variable_get(:@reg).each do |register_value|
        (0..255).should cover register_value
      end
    end
  end

  describe '#scanline' do
    before { clear_tia_registers }

    context 'TIA-CPU integration' do
      it 'should spend 76 CPU cycles generating a scanline' do
        tia.cpu.should_receive(:tick).exactly(76).times

        tia.scanline
      end
    end

    context 'TIA-RIOT integtation' do
      it 'should tick RIOT 76 times while generating a scanline, regardless of CPU timing' do
        tia.riot.should_receive(:tick).exactly(76).times

        tia.scanline
      end

      it 'should tick RIOT even if CPU is frozen by a write to WSYNC' do
        tia.cpu.stub(:tick) { tia[WSYNC] = rand(256) }
        tia.riot.should_receive(:tick).exactly(76).times

        tia.scanline
      end
    end

    context 'PF0, PF1, PF2' do
      before do
        tia[COLUBK] = 0xBB
        tia[COLUPF] = 0xFF
      end

      context 'all-zeros playfield' do
        it 'should generate a fullscanline with background color' do
          tia.scanline.should == Array.new(160, 0xBB)
        end
      end

      context 'all-ones playfield' do
        before { tia[PF0] = tia[PF1] = tia[PF2] = 0xFF }

        it 'should generate a fullscanline with foreground color' do
          tia.scanline.should == Array.new(160, 0xFF)
        end
      end

      context 'pattern playfield' do
        before do
          tia[PF0] = 0b01000101
          tia[PF1] = 0b01001011
          tia[PF2] = 0b01001011
        end

        it 'should generate matching pattern' do
          tia.scanline.should == [0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xFF, 0xFF, 0xFF, 0xFF, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xFF, 0xFF, 0xFF, 0xFF, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xFF, 0xFF, 0xFF, 0xFF, 0xBB, 0xBB, 0xBB, 0xBB, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xBB, 0xBB, 0xBB, 0xBB, 0xFF, 0xFF, 0xFF, 0xFF, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xFF, 0xFF, 0xFF, 0xFF, 0xBB, 0xBB, 0xBB, 0xBB,
                                  0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xFF, 0xFF, 0xFF, 0xFF, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xFF, 0xFF, 0xFF, 0xFF, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xFF, 0xFF, 0xFF, 0xFF, 0xBB, 0xBB, 0xBB, 0xBB, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xBB, 0xBB, 0xBB, 0xBB, 0xFF, 0xFF, 0xFF, 0xFF, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xFF, 0xFF, 0xFF, 0xFF, 0xBB, 0xBB, 0xBB, 0xBB]
        end
      end
    end

    context 'WSYNC' do
      it 'should halt the CPU if WSYNC is written to' do
        tia.cpu.should_receive(:halted=).with(true)

        tia[WSYNC] = rand(256)
      end

      it 'should "un-halt" the CPU before starting a new scanline (i.e., before its horizontal blank)' do
        tia.cpu.should_receive(:halted=).with(false) do
          tia.should_receive(:wait_horizontal_blank)
        end

        tia.scanline
      end
    end

    context 'VBLANK' do
      before do
        tia[COLUBK] = 0xBB
        tia[COLUPF] = 0xFF
        tia[PF0]    = 0xF0
        tia[PF1]    = 0xFF
        tia[PF2]    = 0xFF
      end

      it 'should generate a black scanline when "blanking" bit is set' do
        tia[VBLANK] = rand_with_bit(1, :set)

        tia.scanline.should == Array.new(160, 0x00)
      end

      it 'should generate a normal scanline when "blanking" bit is clear' do
        tia[VBLANK] = rand_with_bit(1, :clear)

        tia.scanline.should == Array.new(160, 0xFF)
      end

      pending "Latches: INPT4-INPT5 bit (6) and INPT6-INPT7 bit(7)"
    end

    it 'late hblank shifts everything'
  end

  describe '#topmost_pixel' do
    context 'CTRLPF priority bit clear' do
      before { tia[CTRLPF] = rand(256) & 0b100 }

      it { tia.should be_using_priority [:p0, :m0, :p1, :m1, :bl, :pf, :bk] }
    end

    context 'CTRLPF priority bit set' do
      before { tia[CTRLPF] = rand(256) | 0b100 }

      it { tia.should be_using_priority [:pf, :bl, :p0, :m0, :p1, :m1, :bk] }
    end

    class Ruby2600::TIA
      def using_priority?(enabled, others = [])
        # Assuming color = priority for enabled pixels and nil for others...
        enabled.count.times { |i| instance_variable_set "@#{enabled[i]}_pixel", i }
        others.each { |p| instance_variable_set "@#{p}_pixel", nil }
        # ...the first one (color = 0) should be the topmost...
        return false unless topmost_pixel == 0
        puts "DEBUG: Priority checked for #{enabled.first}"
        # ...and we disable it to recursively check the others, until none left
        first = enabled.shift
        first.nil? ? using_priority?(enabled, others << first) : true
      end
    end
  end


  # The "ideal" NTSC frame has 259 scanlines (+3 of vsync, which we don't return),
  # but we should allow some leeway (we won't emulate "screen roll" that TVs do
  # with irregular frames)

  describe '#frame' do
    def build_frame(lines)
      @counter ||= -10 # Start on the "previous" frame
      @counter += 1
      case @counter
      when 0, lines + 3 then tia[VSYNC] = rand_with_bit(1, :set)   # Begin frame
      when 3            then tia[VSYNC] = rand_with_bit(1, :clear) # End frame
      end
      tia[WSYNC] = 255 # Finish scanline      
    end

    258.upto(260).each do |lines|
      xit "should generate a frame with #{lines} scanlines" do
        tia.cpu.stub(:tick) { build_frame(lines) }

        tia[VSYNC] = rand_with_bit 1, :clear
        tia.frame
        tia.frame.size.should == lines
      end
    end
  end
end
