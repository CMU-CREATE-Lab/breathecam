module ApplicationHelper

  def stringToHex(string)
    string.unpack('U'*string.length).collect {|x| x.to_s 16}.join
  end


  def hexToString(hex)
    hex.unpack('a2'*(hex.size/2)).collect {|i| i.hex.chr}.join
  end

end
