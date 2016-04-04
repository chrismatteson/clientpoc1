Facter.add(:datacenter) do
  setcode do
    Facter.value(:hostname)[0]
  end
end
