#
#
# sample script for mptcp implementation on ns-2
#
#      Yoshifumi Nishida <nishida@sfc.wide.ad.jp>
#
#


set ns [new Simulator]

#
# specify to print mptcp option information
#
Trace set show_tcphdr_ 2

#
# setup trace files
#
set f [open out.tr w]
$ns trace-all $f
set nf [open out.nam w]
$ns namtrace-all $nf







#
# mptcp sender
#
set n0 [$ns node]
set n0_0 [$ns node]
set n0_1 [$ns node]
$n0 color red
$n0_0 color red
$n0_1 color red
$ns multihome-add-interface $n0 $n0_0
$ns multihome-add-interface $n0 $n0_1

#
# mptcp receiver
#
set n1 [$ns node]
set n1_0 [$ns node]
set n1_1 [$ns node]
$n1 color blue
$n1_0 color blue
$n1_1 color blue
$ns multihome-add-interface $n1 $n1_0
$ns multihome-add-interface $n1 $n1_1

#
# normal tcp 1
#
set n2 [$ns node]
set n3 [$ns node]
$n2 color yellow
$n3 color yellow

#
# normal tcp 2
#
set n4 [$ns node]
set n5 [$ns node]
$n4 color green
$n5 color green

#
# intermediate nodes 
#
set r1 [$ns node]
set r2 [$ns node]
set r3 [$ns node]
set r4 [$ns node]


$ns duplex-link $n2 $r1 10Mb 5ms DropTail
$ns duplex-link $r3 $n3 10Mb 5ms DropTail
$ns duplex-link $n4 $r2 10Mb 5ms DropTail
$ns duplex-link $r4 $n5 10Mb 5ms DropTail

$ns duplex-link $n0_0 $r1 10Mb 5ms DropTail
$ns duplex-link $r1 $r3   1Mb 5ms DropTail
$ns queue-limit $r1 $r3 30
$ns duplex-link $n1_0 $r3 10Mb 5ms DropTail

$ns duplex-link $n0_1 $r2 10Mb 5ms DropTail
$ns duplex-link $r2 $r4   1Mb 5ms DropTail
$ns queue-limit $r2 $r4 30
$ns duplex-link $n1_1 $r4 10Mb 5ms DropTail







#
# create mptcp sender
#
#     1. create subflows with Agent/TCP/FullTcp/Sack/Multipath
#     2. attach subflow on each interface
#     3. create mptcp core 
#     4. attach subflows to mptcp core
#     5. attach mptcp core to core node 
#     6. attach application to mptcp core
#
set tcp0 [new Agent/TCP/FullTcp/Sack/Multipath]
$tcp0 set window_ 100 
$ns attach-agent $n0_0 $tcp0
set tcp1 [new Agent/TCP/FullTcp/Sack/Multipath]
$tcp1 set window_ 100
$ns attach-agent $n0_1 $tcp1
set mptcp [new Agent/MPTCP]
$mptcp attach-tcp $tcp0
$mptcp attach-tcp $tcp1
$ns multihome-attach-agent $n0 $mptcp
set ftp [new Application/FTP]
$ftp attach-agent $mptcp


#
# create mptcp receiver
#
set mptcpsink [new Agent/MPTCP]
set sink0 [new Agent/TCP/FullTcp/Sack/Multipath]
$ns attach-agent $n1_0 $sink0 
set sink1 [new Agent/TCP/FullTcp/Sack/Multipath]
$ns attach-agent $n1_1 $sink1 
$mptcpsink attach-tcp $sink0
$mptcpsink attach-tcp $sink1
$ns multihome-attach-agent $n1 $mptcpsink
$ns multihome-connect $mptcp $mptcpsink
$mptcpsink listen


#
# create sack TCP connection
#
set reno0 [new Agent/TCP/FullTcp/Sack]
$reno0 set window_ 100 
$ns attach-agent $n2 $reno0
set renosink0 [new Agent/TCP/FullTcp/Sack]
$ns attach-agent $n3 $renosink0
$ns connect $reno0 $renosink0
$renosink0 listen
set ftp0 [new Application/FTP]
$ftp0 attach-agent $reno0


#
# create sack TCP connection
#
set reno1 [new Agent/TCP/FullTcp/Sack]
$reno1 set window_ 100 
$ns attach-agent $n4 $reno1
set renosink1 [new Agent/TCP/FullTcp/Sack]
$ns attach-agent $n5 $renosink1
$ns connect $reno1 $renosink1
$renosink1 listen
set ftp1 [new Application/FTP]
$ftp1 attach-agent $reno1

proc finish {} {
	global ns f 
	global nf
	$ns flush-trace
	close $f
	close $nf

    set awkcode {
        {
           if ($1 == "r" && NF == 20) {  
             if ($3 == "1" && $4 == "10" && $5 == "tcp") { 
               print $2, $18 >> "mptcp"
             } 
             if ($3 == "2" && $4 == "11" && $5 == "tcp") { 
               print $2, $18 >> "mptcp"
             } 
           }
           if ($1 == "r" && NF == 17) {  
             if ($3 == "6" && $4 == "10" && $5 == "tcp") { 
               print $2, $11 >> "normal-tcp1"
             } 
             if ($3 == "8" && $4 == "11" && $5 == "tcp") { 
               print $2, $11 >> "normal-tcp2"
             } 
          }
        }
    } 
	exec rm -f mptcp normal-tcp1 normal-tcp2
    exec awk $awkcode out.tr
    exec xgraph -M -m -nl mptcp normal-tcp1 normal-tcp2 
	exit
}

$ns at 0.1 "$ftp start"        
$ns at 0.1 "$ftp0 start"  
$ns at 0.1 "$ftp1 start" 
$ns at 100 "finish"

$ns run
