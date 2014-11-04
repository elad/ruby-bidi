#!/usr/bin/ruby
require 'weakref'

class WeakHashMap
  def initialize
    @internalHash=Hash.new
    @mutex=Mutex.new
  end 

  class RefDetails
    attr_reader :key, :value
    def initialize (hash, key, value)

      @hash = hash
      @key = key
      @value = value
      begin
        ObjectSpace.define_finalizer(value, proc {@hash.delete(@key)});
      rescue ArgumentError
      end
    end
  end

  def []= key, value
    refDetails=RefDetails.new @internalHash, key, value
    ref=WeakRef.new (refDetails)
    @mutex.synchronize do
      @internalHash[key]=ref
    end
  end

  def [] key
    ref=@internalHash[key]
    return nil unless ref
    GC.disable
    unless ref.weakref_alive? {
      GC.enable
      return nil
    }

    ret_value = ref.__getobj__.value
    GC.enable
    ret_value
  end

  def delete key
    @mutex.synchronize do
       @internalHash.delete key
    end
  end
end

end
