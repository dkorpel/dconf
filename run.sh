set -e

echo "Running example 0"
dmd -i -g -preview=dip1000 -run dconf24/ex0_tempbuf.d

echo "Running example 1"
dmd -i -g -preview=dip1000 -run dconf24/ex1_return.d

echo "Running example 2"
dmd -i -g -preview=dip1000 -run dconf24/ex2_range.d

echo "Running example 3"
dmd -i -g -preview=dip1000 -run dconf24/ex3_stringz.d

echo "Running example 4"
dmd -i -g -preview=dip1000 -run dconf24/ex4_appending.d
