Diagrams are generated by [rr](https://github.com/GuntherRademacher/rr).

Before generation, the symbols and keywords in Parser are replace with the ones in Lexer, through an oneliner shell cmd:
```shell
sed -n -e '50d;51d;' -e'32,120p' sql-grammar/SQLLexer.g4 | awk '{print substr($0, 1, length($0)-1)}' | sed 's/: / /g' |awk '{ print length($1), $0 }' | sort -n -s -r | awk '{ print $2,$3}' | while IFS=' ' read -r key value; do
    # remove unwanted characters
    value=${value//\'/}
    value=${value//\//\\/}
    #echo "-$key- =$value="
    sed -i "" "s/$key/'$value'/g" sql-grammar/SQLParser.g4
    done
```
