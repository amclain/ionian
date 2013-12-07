shared_examples "socket extension interface" do
  
  it { should respond_to :reuse_addr  }
  it { should respond_to :reuse_addr? }
  it { should respond_to :reuse_addr= }
  
  it { should respond_to :ttl  }
  it { should respond_to :ttl? }
  it { should respond_to :ttl= }
  
  # TCP
  
  it { should respond_to :no_delay  }
  it { should respond_to :no_delay? }
  it { should respond_to :no_delay= }
  
  it { should respond_to :cork  }
  it { should respond_to :cork? }
  it { should respond_to :cork= }
  
  # IPv4 Multicast
  
  it { should respond_to :ip_add_membership }
  
  it { should respond_to :ip_drop_membership }
  
  it { should respond_to :ip_multicast_if  }
  it { should respond_to :ip_multicast_if= }
  
  it { should respond_to :ip_multicast_ttl  }
  it { should respond_to :ip_multicast_ttl= }
  
  it { should respond_to :ip_multicast_loop  }
  it { should respond_to :ip_multicast_loop? }
  it { should respond_to :ip_multicast_loop= }
  
  # IPv6 Multicast
  
  it { should respond_to :ipv6_add_membership  }
  
  it { should respond_to :ipv6_drop_membership  }
  
  it { should respond_to :ipv6_multicast_if  }
  it { should respond_to :ipv6_multicast_if= }
  
  it { should respond_to :ipv6_multicast_hops  }
  it { should respond_to :ipv6_multicast_hops= }
  
  it { should respond_to :ipv6_multicast_loop  }
  it { should respond_to :ipv6_multicast_loop? }
  it { should respond_to :ipv6_multicast_loop= }
  
end
