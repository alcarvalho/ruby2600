require 'spec_helper'

describe Ruby2600::TIAPlayer do

  let(:tia) { [] }
  subject(:player) { Ruby2600::TIAPlayer.new(tia) }

  describe 'pixel' do
    it 'should never output if GRP0 is all zeros' do
      tia[GRP0] = 0
      300.times { player.pixel.should be_nil }
    end

    context 'single player drawing' do
      before do
        tia[GRP0] = 0b01010101             # A checkerboard pattern
        tia[NUSIZ0] = 0                    # no repetition
        tia[COLUP0] = rand(256)            # whatever color
        rand(160).times { player.pixel }   # at an arbitrary screen position
        player.strobe
      end

      it 'after a strobe, it should output the player after a full scanline (160pixels) + 1-bit delay' do
        5.times { player.pixel }   # clocking/latching should take 5 CLK
        160.times { |i| puts i; player.pixel.should be_nil } # should have no player on this scanline
        player.pixel.should be_nil # player drawing is delayed by 1 pixel
        4.times do
          player.pixel.should be_nil
          player.pixel.should == tia[COLUP0]
        end
      end

      it 'should keep outputing the player on subsequent scanlines' do
        166.times { player.pixel } # 5+160+1, see above
        10.times do
          4.times do
            player.pixel.should be_nil
            player.pixel.should == tia[COLUP0]
          end
          152.times { player.pixel } # Next player should be at 160 - (4 x 2)
        end
      end
    end
  end
end
