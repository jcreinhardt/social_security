clear all
gl main = "/Users/rceyfk01/Dropbox/SSA-INCOME-RISK/Replication/Final/PSID"
gl sep = "/"
gl output = "${main}${sep}Output${sep}"
gl code = "${main}${sep}Code${sep}"
gl inter = "${main}${sep}Intermediate${sep}"
gl logf = "${main}${sep}LogFiles${sep}"

cd $code
do process_family_files.do

cd $code
do topcoding.do

cd $code
do process_individual_files.do

cd $code
do merge_family_individual.do

cd $code
do make_annual.do

cd $code
do clean_data.do

cd $code
do higher_order_moments_6groups.do
