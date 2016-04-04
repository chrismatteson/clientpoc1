Facter.add(:datacenter) do
  setcode do
    Facter.value(:hostname)[0..2]
  end
end
