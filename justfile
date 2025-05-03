default: clean package

clean:
    rm -rf lit_dist
    rm -rf snp-release-*
    rm -rf firmware

firmware:
    mkdir -p firmware
    wget -P firmware -O firmware/amd_sev_fam19h_model0xh_1.55.29.zip https://download.amd.com/developer/eula/sev/amd_sev_fam19h_model0xh_1.55.29.zip # MILAN
    wget -P firmware -O firmware/amd_sev_fam19h_model1xh_1.55.39.zip https://download.amd.com/developer/eula/sev/amd_sev_fam19h_model1xh_1.55.39.zip # GENOA
    unzip -o firmware/amd_sev_fam19h_model0xh_1.55.29.zip -d firmware
    unzip -o firmware/amd_sev_fam19h_model1xh_1.55.39.zip -d firmware
    cp firmware/amd_sev_fam19h_model0xh_1.55.29.sbin firmware/amd_sev_fam19h_model0xh.sbin
    cp firmware/amd_sev_fam19h_model1xh_1.55.39.sbin firmware/amd_sev_fam19h_model1xh.sbin

build:
    # install build dependencies
    sudo apt-get update
    sudo apt-get install -y python3-sphinx ninja-build libglib2.0-dev # amdsev/qemu
    sudo apt-get install -y uuid-dev nasm acpica-tools gcc-multilib nasm # ovmf
    sudo apt-get install -y bison flex libelf-dev # linux
    sudo apt-get install -y libslirp-dev # optional for default networking in a VM

    # build amdsev distribution
    ./build.sh --package

# Create a distribution bundle of the current release and firmware
bundle: firmware build
    mkdir -p lit_dist/packages
    mkdir -p lit_dist/packages/firmware
    mkdir -p lit_dist/packages/snp-release-current
    # copy snp-release to lit_dist/snp-current
    cp -r snp-release-$(date +%Y-%m-%d) lit_dist/packages/snp-release-current
    # copy firmware to lit_dist/firmware
    cp firmware/amd_sev_fam19h_model0xh.sbin lit_dist/packages/firmware/
    cp firmware/amd_sev_fam19h_model1xh.sbin lit_dist/packages/firmware/

package: bundle
    if [ ! -d "lit_dist" ]; then echo "Error: lit_dist folder does not exist. Run 'just bundle' to create a new bundle" && exit 1; fi
    tar -czf amd-tee-packages_debian-12-$(date +%y%m%d).tar.gz -C lit_dist .

# Deploy the current bundle to this machine so `lit os update` will install it
# NOTE: Deployment is tightly coupled to the lit-os repo, this is written against commit d88c59df
deploy:
    if [ ! -d "lit_dist" ]; then echo "Error: lit_dist folder does not exist. Run 'just bundle' to create a new bundle" && exit 1; fi
    sudo rm -rf /usr/local/src/amd/packages && sudo mkdir -p /usr/local/src/amd/packages
    sudo cp -r lit_dist/* /usr/local/src/amd/packages
    # delete marker files
    sudo rm /var/local/litos-tee.install || true
    sudo rm /var/local/litos-tee.install || true
    sudo lit os update

# Install the current bundle to this machine manually (without `lit os update`)
install:
    if [ ! -d "lit_dist" ]; then echo "Error: lit_dist folder does not exist. Run 'just bundle' to create a new bundle" && exit 1; fi
    # install firmware
    sudo mkdir -p /lib/firmware/amd
    sudo cp lit_dist/firmware/*.sbin /lib/firmware/amd
    # install kernel
    sudo apt-get update
    sudo apt-get install git xz-utils python-is-python3 equivs rsync zip cloud-image-utils bridge-utils uml-utilities -y # RAD: these may not (all) be needed
    sudo dpkg -i lit_dist/snp-release-current/linux/host/*.deb
    # install qemu user tools
    sudo rm -rf /opt/AMDSEV
    sudo mkdir -p /opt/AMDSEV
    sudo cp -rf lit_dist/snp-release-current/launch-qemu.sh /opt/AMDSEV/
    sudo cp -rf lit_dist/snp-release-current/usr /opt/AMDSEV/
