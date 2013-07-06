require 'spec_helper'

describe Ruby2600::TIAPlayer do

  let(:tia) { [] }
  subject(:player) { Ruby2600::TIAPlayer.new(tia) }

  def player_pixels(n)
    (1..n).map { |i| puts "will test grp bit #{8-i}"; player.pixel }
  end

  describe 'pixel' do
    it 'should never output if GRP0 is all zeros' do
      tia[GRP0] = 0
      300.times { player.pixel.should be_nil }
    end

    context 'single player drawing' do
      before do
        tia[GRP0] = 0b01010101             # A checkerboard pattern
        tia[NUSIZ0] = 0                    # no repetition
        tia[COLUP0] = 0xEE                 # whatever color
        rand(160).times { player.pixel }   # at an arbitrary screen position
        player.strobe
      end

      it 'after a strobe, it should output the player after a full scanline (160pixels) + 1-bit delay' do
        # Player is drawn on next scanline (160 pixels), delayed by 1 pixel
        161.times { player.pixel.should be_nil }
        player_pixels(8).should == [nil, 0xEE, nil, 0xEE, nil, 0xEE, nil, 0xEE]
      end

      it 'should draw player again on second-after-current scanline' do
        321.times { player.pixel }
        player_pixels(8).should == [nil, 0xEE, nil, 0xEE, nil, 0xEE, nil, 0xEE]
      end

      it 'should draw player on third-after-current scanline' do
        481.times { player.pixel }
        player_pixels(8).should == [nil, 0xEE, nil, 0xEE, nil, 0xEE, nil, 0xEE]
      end
    end
  end
end
