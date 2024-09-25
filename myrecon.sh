#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' 

# Banner
text_MMHR=$(figlet -f slant MMHR)
echo -e "${BLUE}${text_MMHR}${NC}"
echo -e "${GREEN}└──────$ created by Mahmoud Elsady${NC}"

# Help Menu
show_help() {
    echo -e "     ${BLUE}Usage: $0 [options] <domain>${NC}"
    echo -e "     	${GREEN}Options:${NC}"
    echo -e "     		${YELLOW}-h,   --help         Display this help message${NC}"
    echo -e "     		${YELLOW}-sub, --subdomain    Run all tools for the given domain${NC}"
    echo -e "     		${YELLOW}-d, --dirb       Run dirb on the specified file${NC}"
    echo -e "     		${YELLOW}-p,   --parameter   Run parameter discovery tools${NC}"
    echo -e "     		${YELLOW}-r,   --replace   Run qsreplace tools${NC}"
    echo -e "     		${YELLOW}-purl, --pasturl   Fetch URLs from Wayback Machine${NC}"
    echo -e "     		${YELLOW}-i,   --info       Gather information using whatweb${NC}"
    echo -e "     		${YELLOW}-f,   --waf        Detect WAFs (Web Application Firewalls)${NC}"
    echo -e "     ${GREEN}Example: $0 --subdomain example.com${NC}"
    echo -e "     ${GREEN}Example: $0 --dirb example.com${NC}"
    echo -e "     ${GREEN}Example: $0 --dirb example.com /usr/share/wordlists${NC}"
    echo -e "     ${GREEN}Example: $0 --parameter example.com${NC}"
    echo -e "     ${GREEN}Example: $0 --parameter ./subdomains.txt${NC}"
    echo -e "     ${GREEN}Example: $0 --replace <path_file> <word_want_replace>${NC}"
    echo -e "     ${GREEN}Example: $0 --replace <path_file1> <path_file2> <word_want_replace>${NC}"
    echo -e "     ${GREEN}Example: $0 --pasturl example.com${NC}"
    echo -e "     ${GREEN}Example: $0 --pasturl ./domains.txt${NC}"
    echo -e "     ${GREEN}Example: $0 --info example.com${NC}"
    echo -e "     ${GREEN}Example: $0 --waf example.com${NC}"
    echo -e "     ${GREEN}Example: $0 --waf ./subdomains.txt${NC}"
}

# Check if tools are installed
check_tools() {
    local tools=("subfinder" "assetfinder" "sublist3r" "httpx" "httprobe" "dirb" "paramspider" "arjun" "sed" "waybackurls" "whatweb" "wafw00f")
    local missing_tools=()

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo -e "${RED}[xxx]Error: The following tools are missing:${NC}"
        for tool in "${missing_tools[@]}"; do
            echo -e "${RED}  - $tool${NC}"
        done
        echo -e "${YELLOW}Please install these tools and try again.${NC}"
        exit 1
    fi
}

# Initialize variables
DOMAIN=""
RUN_TOOLS=0
RUN_DIRB=0
RUN_PARAM=0
RUN_REPLACE=0
PARAM_TARGET=""
DIRB_FILE=""
REPLACE_FILE=""
FILES=()
REPLACE_WORD=""
RUN_PASTURL=0
PASTURL_TARGET=""
RUN_INFO=0
INFO_TARGET=""
RUN_WAF=0
WAF_TARGET=""

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        --subdomain|-sub)
            RUN_TOOLS=1
            DOMAIN="$2"
            shift
            ;;
        -d|--dirb)
            RUN_DIRB=1
            DOMAIN="$2"
            shift
            ;;
        --parameter|-p)
            RUN_PARAM=1
            PARAM_TARGET="$2"
            shift
            ;;
        --replace|-r)
            RUN_REPLACE=1
            shift
            while [[ $# -gt 1 ]]; do
                FILES+=("$1")
                shift
            done
            REPLACE_WORD="$1"
            ;;
        --pasturl|-purl)
            RUN_PASTURL=1
            PASTURL_TARGET="$2"
            shift
            ;;
        --info|-i)
            RUN_INFO=1
            INFO_TARGET="$2"
            shift
            ;;
        --waf|-f)
            RUN_WAF=1 
            WAF_TARGET="$2"
            shift
            ;;
        *)
            if [ -z "$DOMAIN" ] && [ $RUN_TOOLS -eq 1 ]; then
                DOMAIN="$1"
            elif [ -z "$DIRB_FILE" ] && [ $RUN_DIRB -eq 1 ]; then
                DIRB_FILE="$1"
            elif [ -z "$PARAM_TARGET" ] && [ $RUN_PARAM -eq 1 ]; then
                PARAM_TARGET="$1"
            elif [ -z "$REPLACE_FILE" ] && [ $RUN_REPLACE -eq 1 ]; then
                REPLACE_FILE="$1"
            elif [ -z "$PASTURL_TARGET" ] && [ $RUN_PASTURL -eq 1 ]; then
                PASTURL_TARGET="$1"
            elif [ -z "$INFO_TARGET" ] && [ $RUN_INFO -eq 1 ]; then
                INFO_TARGET="$1"
            elif [ -z "$WAF_TARGET" ] && [ $RUN_WAF -eq 1 ]; then
                WAF_TARGET="$1"
            else
                echo -e "${RED}[xxx]Error: Invalid option or argument: $1${NC}"
                show_help
                exit 1
            fi
            ;;
    esac
    shift
done

# Check if any action is specified
if [ $RUN_TOOLS -eq 0 ] && [ $RUN_DIRB -eq 0 ] && [ $RUN_PARAM -eq 0 ] && [ $RUN_REPLACE -eq 0 ] && [ $RUN_PASTURL -eq 0 ] && [ $RUN_INFO -eq 0 ] && [ $RUN_WAF -eq 0 ]; then
    echo -e "${RED}[x]Error: No valid option specified.${NC}"
    show_help
    exit 1
fi

# Check if tools are installed
check_tools

# Variables
OUTPUT_DIR="output_${DOMAIN}"
MERGED_FILE="$OUTPUT_DIR/merged.txt"
HTTPX_OUTPUT="$OUTPUT_DIR/httpx_results.txt"
HTTPROBE_OUTPUT="$OUTPUT_DIR/httprobe_results.txt"
FINAL_MERGED_FILE="$OUTPUT_DIR/final_results.txt"
result_target="result_${DOMAIN}"
# Create output directory based on domain name
if [ -z "$result_target" ]; then
    echo "Error: result_target variable is not set"
    exit 1
fi
mkdir -p $result_target

# Run tools and save outputs
if [ $RUN_TOOLS -eq 1 ]; then
    echo -e "${BLUE}[+]Running Subfinder...${NC}"
    subfinder -d $DOMAIN -o $OUTPUT_DIR/subfinder.txt

    echo -e "${BLUE}[+]Running Assetfinder...${NC}"
    assetfinder $DOMAIN > $OUTPUT_DIR/assetfinder.txt

    echo -e "${BLUE}[+]Running Sublist3r...${NC}"
    sublist3r -d $DOMAIN -o $OUTPUT_DIR/sublist3r.txt

    # Merge files and remove duplicates
    echo -e "${YELLOW}[+]Merging files and removing duplicates...${NC}"
    cat $OUTPUT_DIR/subfinder.txt \
        $OUTPUT_DIR/assetfinder.txt \
        $OUTPUT_DIR/sublist3r.txt | sort -u > $MERGED_FILE

    # Run httpx and httprobe
    echo -e "${BLUE}[+]Running httpx...${NC}"
    httpx -l $MERGED_FILE -o $HTTPX_OUTPUT

    echo -e "${BLUE}[+]Running httprobe...${NC}"
    cat $MERGED_FILE | httprobe > $HTTPROBE_OUTPUT

    # Merge httpx and httprobe results, remove duplicates
    echo -e "${YELLOW}[+]Merging httpx and httprobe results...${NC}"
    cat $HTTPX_OUTPUT $HTTPROBE_OUTPUT | sort -u > $FINAL_MERGED_FILE
fi




# DIRB

if [ $RUN_DIRB -eq 1 ]; then
    if [ -f "$DIRB_FILE" ]; then
        # If DIRB_FILE is a file containing subdomains
        echo -e "${BLUE}[+] Running dirb on each subdomain in $DIRB_FILE...${NC}"
        while IFS= read -r subdomain; do
            # Ensure to trim any leading/trailing whitespace
            subdomain=$(echo "$subdomain" | xargs)
            echo -e "${BLUE}[+] Running dirb on https://$subdomain...${NC}"
            # Create a result file name based on the subdomain
            result_file="${result_target}/dirb_$(echo "$subdomain" | sed 's/[^a-zA-Z0-9]/_/g').txt"
            dirb "https://$subdomain" -f -w /usr/share/wordlists/dirbuster/directory-list-1.0.txt | grep -E '200|301|302' > "$result_file"
            echo -e "${GREEN}[+] Dirb results for $subdomain saved at: $result_file ${NC}"
        done < "$DIRB_FILE"
    else
        # If is a single domain
        echo -e "${BLUE}[+] Running dirb on single domain https://$domain...${NC}"
        dirb "https://$domain" -f -w /usr/share/wordlists/dirbuster/directory-list-1.0.txt | grep -E '200|301|302' > ${result_target}/dirb.txt
        echo -e "${GREEN}[+] Dirb results saved at: ${result_target}/dirb.txt ${NC}"
    fi
fi











# Parameter discovery
if [ $RUN_PARAM -eq 1 ]; then
    if [ -f "$PARAM_TARGET" ]; then
        echo -e "${BLUE}[+] Running paramspider on each subdomain in $PARAM_TARGET...${NC}"
        while IFS= read -r subdomain; do
            echo -e "${BLUE}[+] Running paramspider on $subdomain...${NC}"
            paramspider -d "$subdomain" > $result_target/paramspider_$subdomain.txt
            echo -e "${GREEN}[+] Paramspider discovery results saved at: $result_target/paramspider_$subdomain.txt ${NC}"
        done < "$PARAM_TARGET"
    else
        echo -e "${BLUE}[+] Running arjun on $PARAM_TARGET...${NC}"
        arjun -u "http://$PARAM_TARGET" > $result_target/arjun.txt
        echo -e "${GREEN}[+] Arjun discovery results saved at: $result_target/arjun.txt ${NC}"

        echo -e "${BLUE}[+] Running paramspider on $PARAM_TARGET...${NC}"
        paramspider -d "$PARAM_TARGET" > $result_target/paramspider.txt
        echo -e "${GREEN}[+] Paramspider discovery results saved at: $result_target/paramspider.txt ${NC}"
    fi

    echo -e "${GREEN}Parameter discovery has finished. Results are saved in the $result_target directory.${NC}"
fi


# Perform replacement
if [ $RUN_REPLACE -eq 1 ]; then
    for FILE in "${FILES[@]}"; do
        if [ -f "$FILE" ]; then
            REPLACED_FILE="${FILE%.txt}_replace.txt"
            sed "s/FUZZ/$REPLACE_WORD/g" "$FILE" > "$REPLACED_FILE"
            echo -e "${GREEN}Replacement done. Output saved to $REPLACED_FILE${NC}"
        else
            echo -e "${RED}[xxx]Error: File $FILE does not exist.${NC}"
        fi
    done
fi

if [ $RUN_PASTURL -eq 1 ]; then
    echo -e "${BLUE}[+]Running waybackurls...${NC}"
    if [[ "$PASTURL_TARGET" == *".txt" ]]; then
        cat $PASTURL_TARGET | waybackurls > $result_target/waybackurls_results.txt
    else
        echo "$PASTURL_TARGET" | waybackurls > $result_target/waybackurls_results.txt
    fi
    echo -e "${YELLOW}[+]Waybackurls output saved in $result_target/waybackurls_results.txt"
fi

if [ $RUN_INFO -eq 1 ]; then
    echo -e "${BLUE}[+]Running whatweb...${NC}"
    whatweb $INFO_TARGET > $result_target/whatweb_results.txt
    echo -e "${YELLOW}[+]whatweb output saved in ${INFO_OUTPUT_DIR}/whatweb_results.txt${NC}"
    
    echo -e "${BLUE}[+]Running whois...${NC}"
    whois $INFO_TARGET > $result_target/whois_results.txt
    echo -e "${YELLOW}[+]whois output saved in ${INFO_OUTPUT_DIR}/whois_results.txt${NC}"
fi

if [ $RUN_WAF -eq 1 ]; then
    echo -e "${BLUE}[+]Running wafw00f...${NC}"
    if [[ "$WAF_TARGET" == *".txt" ]]; then
        while IFS= read -r subdomain; do
            if [[ "$subdomain" != "" ]]; then
                echo -e "${BLUE}[+]Running wafw00f on $subdomain...${NC}"
                wafw00f "http://$subdomain" -v > "${result_target}/$(echo $subdomain | sed 's/[^a-zA-Z0-9]//g')_waf.txt"
                wafw00f "https://$subdomain" -v >> "${result_target}/$(echo $subdomain | sed 's/[^a-zA-Z0-9]//g')_waf.txt"
            fi
        done < "$WAF_TARGET"
    else
        wafw00f "http://$WAF_TARGET" -v > "${result_target}/$(echo $WAF_TARGET | sed 's/[^a-zA-Z0-9]//g')_waf.txt"
        wafw00f "https://$WAF_TARGET" -v >> "${result_target}/$(echo $WAF_TARGET | sed 's/[^a-zA-Z0-9]//g')_waf.txt"
    fi
    echo -e "${YELLOW}[+]Wafw00f output saved in ${result_target}${NC}"
fi
