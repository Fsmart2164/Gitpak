#!/bin/fish
set project_location (cat /etc/gitpak/config)
set repos_json "$project_location/Data/repos.json"
set vgitpak "v0.1.00"
cd $project_location

function get_input
    set -l prompt $argv[1]
    set -l possible_inputs $argv[2..(count $argv)]
    while true
        set input (read -p "echo $prompt")
        if contains $input $possible_inputs
            break
        end
    end
    echo "$input"
end

function list_updates
    set repos (jq -r '.[] | .name' $repos_json )
    set -l updates
    for repo in $repos
        set install_ver (jq -r --arg name "$repo" '.[] | select(.name==$name) | .version' $repos_json)
        set url (jq -r --arg name "$repo" '.[] | select(.name==$name) | .url' $repos_json)

        set current_ver (git ls-remote --tags --sort=-v:refname $url | grep -v '\^{}' | head -n1 | sed 's/.*refs\/tags\///')
        if [ $current_ver != $install_ver ]
            echo $repo: $install_ver "-->" $current_ver
            set -a updates "$repo?$url"
        end
    end
end

if set -q argv[1]
    set choice $argv[1]
else
    echo use --help for details
    return
end

if [ $choice = update ]
    set repos (jq -r '.[] | .name' $repos_json )
    set -l updates
    for repo in $repos
        set install_ver (jq -r --arg name "$repo" '.[] | select(.name==$name) | .version' $repos_json)
        set url (jq -r --arg name "$repo" '.[] | select(.name==$name) | .url' $repos_json)

        set current_ver (git ls-remote --tags --sort=-v:refname $url | grep -v '\^{}' | head -n1 | sed 's/.*refs\/tags\///')
        if [ $current_ver != $install_ver ]
            echo $repo: $install_ver "-->" $current_ver
            set -a updates "$repo?$url"
        else
            echo $repo is up to date
        end
    end

    if not [ "$updates" = "" ]
        set input (get_input "echo Would you like gitpak to update? [Y/n]:" Y n)
        if not [ $input = Y ]
            return
        end
        sudo rm -rf Repos
        mkdir -p Repos
        cd Repos
        set total (count $updates)
        set i 0
        for package in $updates
            set i (math $i + 1)
            set -l package (string split '?' $package)
            set name $package[1]
            set url $package[2]
            set repo_version (git ls-remote --tags --sort=-v:refname $url | grep -v '\^{}' | head -n1 | sed 's/.*refs\/tags\///')

            if [ "$name" = "" ]; or [ "$url" = "" ]
                echo empty entry
                continue
            end

            echo "[$i/$total] Cloning $name..."
            git clone $url
            cd $name

            set exe "$project_location/Data/Install_Commands/$name.fish"
            # run install script
            echo "[$i/$total] Installing $name..."
            sudo fish $exe

            cd ..
            echo attempting to remove leftover files from $name
            sudo rm -rf $name
            echo Removed left over git clone $name
            jq --arg url "$url" --arg version "$repo_version" \
                '(.[] | select(.url==$url) | .version) = $version' \
                $repos_json >"$repos_json.tmp" && mv "$repos_json.tmp" $repos_json
        end
    end

else if [ $choice = install ]
    if not set -q argv[2]
        set url (read -p "echo enter package url:' '")
        if [ "$url" = "" ]
            exit
        end
    else
        set url $argv[2]
    end

    set url_segments (string split '/' $url)
    set name $url_segments[(count $url_segments)]
    set repo_version (git ls-remote --tags --sort=-v:refname $url | grep -v '\^{}' | head -n1 | sed 's/.*refs\/tags\///')

    jq --arg name "$name" --arg url "$url" --arg version "$repo_version" \
        '. + [{"name": $name, "url": $url, "version": $version}]' \
        $repos_json >"$repos_json.tmp" && mv "$repos_json.tmp" $repos_json

    cd Repos
    git clone $url
    cd $name
    echo
    echo now you need to install
    echo when you have installed the program enter the command done
    set exe "$project_location/Data/Install_Commands/$name.fish"
    sudo echo "#!/bin/fish" >$exe
    while true
        set command (read -p "")
        if [ $command = done ]
            break
        end
        echo $command >>$exe
        eval $command
    end
    cat -n $exe
    set confirm (get_input "echo 'Is this the correct install commands? [Y/n]:'" Y n)
    if not [ $confirm = Y ]
        nano $exe
    end
else if [ $choice = lu ]; or [ $choice = list-updates ]
    list_updates
else if [ $choice = --help ]; or [ $choice = -h ]
    cat "$project_location/Data/help.readme"
else if [ $choice = --version]; or [ choice = -v ]
    cat $project_location/Data/logo
    echo Gitpak version $vgitpak
end
