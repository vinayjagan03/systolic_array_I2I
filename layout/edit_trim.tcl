# read verifyConnectivity report to get unique list of nets with dangling or floating metal errors:
set rpt "./top.conn.rpt"
if {[catch {open $rpt "r"} fid]} {
    error "Failed to open file $rpt for read."
} else {
    set allnets {}
    while { [gets $fid line] >= 0 } {
        if {[expr [regexp {^Net\s} $line] && \
                 ([regexp {:\s+special open\s} $line] || \
                  [regexp {:\s+dangling Wire\s} $line])]} {
            regexp {^Net\s+(\S+):} $line match net
            lappend allnets $net
        }
    }
    close $fid

    # sort list of nets to find unique net names
    set nets [lsort -unique $allnets]
    puts "  Found [llength $nets] unique nets from [llength $allnets] nets reported."
    edit_trim_routes -nets $nets
}


