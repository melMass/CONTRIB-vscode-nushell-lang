#!/usr/bin/env nu

# builtin sort functions only sort alphabetically
def sort-by-length [
    column: string
] {
    insert length {get $column|str length}
    |sort-by -r length
    |reject length
}

# generate combined regex for all single word commands
def match-for-single [
    commands:record
] {
    build-string '\b(' ($commands|where ($it.subcommands|length) == 1|sort-by-length command|get command|str collect '|'|str replace -a -s '?' '\?') ')\b'
}

# generate list of regexes for every two word command
def match-for-double [
    commands: record
] {
    $commands
    |where ($it.subcommands|length) > 0 and ($it.subcommands.second-word|all $it != '')|each {|x|
        build-string '\b' $x.command '(\s' ($x.subcommands.second-word|compact|str collect '|\s') ')\b'
    }
}

# returns regexes for all commands, both single and double word single-word append is conditional because some letters only have two word commands e.g 'q'
def generate-matches [
    category: record
] {
    if ($category | get category) ends-with '_sub' {
        match-for-double $category.commands
    } else {
        match-for-single $category.commands
    }
}

let patterns = (
    $nu.scope.commands
    |where is_builtin == true and is_extern == false
    |get command
    |split column ' ' first-word second-word
    |default '' second-word
    |uniq
    |upsert category {|x|
        let first_letter = ($x.first-word|split chars|get 0)
        if $x.second-word == '' {
            $"($first_letter)"
        } else {
            $"($first_letter)_sub"
        }
    }
    |group-by category
    |transpose category commands
    |upsert commands {
        get commands
        |group-by first-word
        |transpose command subcommands
    }
    |reverse
    |each {|category|
        generate-matches $category
        |each {|match|
            {name: $"keyword.other.($category.category)", match: $match}
        }
    }
    |flatten
)

open syntaxes/nushell.tmLanguage.json
|update repository.keywords.patterns $patterns
|save syntaxes/nushell.tmLanguage.json
