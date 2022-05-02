{
  description = "Run a full Cardano blockchain node in a qemu VM";

  # https://status.nixos.org/
  inputs.nixpkgs.url = "github:nixos/nixpkgs/e10da1c7f542515b609f8dfbcf788f3d85b14936";
  inputs.microvm.url = "github:astro/microvm.nix";
  inputs.microvm.inputs.nixpkgs.follows = "nixpkgs";
  inputs.cardano-system.url = "github:cardano-system/cardano-system/lc/nixosModule";

  outputs = { self, nixpkgs, microvm, cardano-system }:
    let
      system = "x86_64-linux";
    in {
      defaultPackage.${system} = self.packages.${system}.cardano-here;

      packages.${system}.cardano-here =
        let
          inherit (self.nixosConfigurations.cardano-here) config;
          # quickly build with another hypervisor if this MicroVM is built as a package
          hypervisor = "qemu";
        in config.microvm.runner.${hypervisor};

      nixosConfigurations.cardano-here = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          microvm.nixosModules.microvm
          {
            networking.hostName = "cardano-here";
            users.users.root.password = "";
            microvm = {
              vcpu = 4;
              mem = 32000;
              volumes = [ {
                mountPoint = "/var";
                image = "var.img";
                size = 10000;
              } ];
              shares = [ {
                # use "virtiofs" for MicroVMs that are started by systemd
                proto = "9p";
                tag = "ro-store";
                # a host's /nix/store will be picked up so that the
                # size of the /dev/vda can be reduced.
                source = "/nix/store";
                mountPoint = "/nix/.ro-store";
              } ];
              socket = "control.socket";
              # relevant for delarative MicroVM management
              hypervisor = "qemu";
            };
          }
          cardano-system.nixosModule.x86_64-linux
          {
            services.cardano-system.enable = true;
            services.cardano-system.library.enable = true;
          }
        ];
      };
    };
}
