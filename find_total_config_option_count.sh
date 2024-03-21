find ~/linux-next -name 'Kconfig*' -exec grep -h '^config ' {} \; | sort | uniq | wc -l
