#!/bin/bash

CHECK=$(mount | grep /media/vmusb | cut -d ' ' -f 4)
if [ "$CHECK" != "type" ]
then
        USBDRIVE=$(mount | grep /run/media | cut -d ' ' -f 1)
        FS=$(mount | grep $USBDRIVE | cut -d ' ' -f 5)
        if [[ $FS == 'ext2' || $FS == 'ext3' || $FS == 'ext4' || $FS == 'xfs' ]]
        then
                if [ -e /media/vmusb/ ]
                then
                        umount $USBDRIVE && mount $USBDRIVE /media/vmusb
                else
                        mkdir /media/vmusb && umount $USBDRIVE && mount $USBDRIVE /media/vmusb
                fi
        else
                echo !!!!!"change USB FS type to xfs-ext4-ext3-ext2-other for >4G archives"!!!!!
        fi
fi
CHECK2=$(mount | grep /media/vmusb | cut -d ' ' -f 2)
if [ "$CHECK2" == "on" ]
then
	COUNTER=3
        until [ $COUNTER -lt 3 ] ; do
		eval COLUMN=$COUNTER
               		VMNAME=$(virsh list --all | awk '{print $2}' | sed -n "${COLUMN}p")
              		VMSTAT=$(virsh list --all | awk '{print $3}' | sed -n "${COLUMN}p")
                        LVM=$(virsh domblklist $VMNAME | grep vda | cut -d ' ' -f 9)
                       	LVMNAME=$(virsh domblklist $VMNAME | grep vda | cut -d ' ' -f 9 | cut -d '/' -f 4)
                        LVMSIZE=$(lvdisplay $LVM | grep 'LV Size' | cut -d ' ' -f 20 | cut -d '.' -f 1)
                        LVMSIZEB=$(virsh domblkinfo $VMNAME $LVM | grep Capacity | cut -d ' ' -f 8)
				if [ "$VMSTAT" == "shut" ]
                                then
                                	if [ -e /media/vmusb/$VMNAME.bz2 ]
                                        then
						echo VMNAME "$VMNAME", LVM "$LVM", LVMSIZEB "$LVMSIZEB" > /media/vmusb/"$VMNAME"_$(date +%y%m%d).info
						virsh dumpxml $VMNAME > /media/vmusb/"$VMNAME"_xmldump_$(date +%y%m%d).xml ; ls /media/vmusb
                                        else
						SNAPSIZE=$(( $LVMSIZE * 32 ))
						lvcreate -s -n "$LVMNAME"_snap -L"$SNAPSIZE"M "$LVM" & echo !!!!!!!COPYING DATA PLEASE WAIT!!!!!!! && wait &&
						dd if="$LVM"_snap bs=128M conv=notrunc,noerror | bzip2 -ck -3 > /media/vmusb/"$VMNAME".bz2 && wait &&
						lvremove -f "$LVM"_snap
						echo VMNAME "$VMNAME", LVM "$LVM", LVMSIZEB "$LVMSIZEB" > /media/vmusb/"$VMNAME"_$(date +%y%m%d).info
						virsh dumpxml $VMNAME > /media/vmusb/"$VMNAME"_xmldump_$(date +%y%m%d).xml ; ls /media/vmusb
                                        fi
                                 elif [ "$VMSTAT" == "running" ]
                                 then
                                        if [ -e /media/vmusb/$VMNAME.bz2 ]
                                        then
						virsh save "$VMNAME" /media/vmusb/"$VMNAME"_$(date +%y%m%d).vmstate --running &&
						virsh restore /media/vmusb/"$VMNAME"_$(date +%y%m%d).vmstate
						echo VMNAME "$VMNAME", LVM "$LVM", LVMSIZEB "$LVMSIZEB" > /media/vmusb/"$VMNAME"_$(date +%y%m%d).info
						virsh dumpxml $VMNAME > /media/vmusb/"$VMNAME"_xmldump_$(date +%y%m%d).xml ; ls /media/vmusb
				 	else
                                        	SNAPSIZE=$(( $LVMSIZE * 32 ))
                                                virsh save "$VMNAME" /media/vmusb/"$VMNAME"_$(date +%y%m%d).vmstate --running &&
						lvcreate -s -n "$LVMNAME"_snap -L"$SNAPSIZE"M "$LVM" &&
						virsh restore /media/vmusb/"$VMNAME"_$(date +%y%m%d).vmstate &
						echo !!!!!!!COPYING DATA PLEASE WAIT!!!!!!! && wait &&
						dd if="$LVM"_snap bs=128M conv=notrunc,noerror | bzip2 -ck -3 > /media/vmusb/"$VMNAME".bz2 && wait &&
						lvremove -f "$LVM"_snap
						echo VMNAME "$VMNAME", LVM "$LVM", LVMSIZEB "$LVMSIZEB" > /media/vmusb/"$VMNAME"_$(date +%y%m%d).info
						virsh dumpxml $VMNAME > /media/vmusb/"$VMNAME"_xmldump_$(date +%y%m%d).xml ; ls /media/vmusb
                                 	fi
                  		 else
                                        break
                                 fi
			let COUNTER+=1
		done
fi
