from datetime import date
import os

layout_big = """
Hardware & OS
  >  Distro: {distro(architecture=True)}
  >  Kernel: {kernel(small=False)}
  > 󰌢 Laptop: {model(version=True)}
  > 󰍹 Monitor: {monitor()} 
  >  GPU: {gpu(colorize=True)} 
  >  CPU: {cpu()}
  >  Memory: {memory()}    
  >  Disk: {disk()}
  >  Driver: {gpu_driver()}   

Software & Misc
  >  WM: {wm()}
  >  Shell: {shell()}
  >  Terminal: {terminal()}
  > 󰔚 Uptime: {uptime()}
  >  Packages: {packages()}
  >  Theme: {gtk_theme()}
  >  Icons: {icon_theme()}
  > 󰸲 Font: {gtk_font()}

  {colors(char="────", normal_only=True, background=False)}
"""

layout2 = """
Hardware & OS
  >  : {distro(architecture=True)}
  >  : {kernel(small=False)}
  > 󰌢 : {model(version=True)}
  > 󰍹 : {monitor()} 
  >  : {gpu(colorize=True)} 
  >  : {cpu()}
  >  : {memory()}    
  >  : {disk()}
  >  : {gpu_driver()}   

Software & Misc
  >  : {wm()}
  >  : {shell()}
  >  : {terminal()}
  > 󰔚 : {uptime()}
  >  : {packages()}
  >  : {gtk_theme()}
  >  : {icon_theme()}
  > 󰸲 : {gtk_font()}

  {colors(char="────", normal_only=True, background=False)}
"""

layout_small = """
 > {distro()}
 > {kernel(small=False)}
 > {wm()}
 > {shell()}
󰔚 > {uptime()}
 > {packages()}

{colors(normal_only=True)}
"""

layout_long = """
╭───────╮
│  krn │ {c8}{kernel(small=False)}
│ {c8} wmg {c2}│ {wm()}
│  shl │ {c8}{shell()}
│ {c8}󰔚 upt {c2}│ {uptime()}
│  pgs │ {c8}{packages()}
│ {c8} gtk {c2}│ {gtk_theme()}
│  ics │ {c8}{icon_theme()}
│ {c8} dis {c2}│ {disk(percent=False, round_mem_to=0)}
│  gpd │ {c8}{gpu_driver()}
╰───────╯
"""

logo_small = {
            "logo": """
         .
        / \\
       /   \\
      /^.   \\
     /  .-.  \\
    /  (   ) _\\
   / _.~   ~._^\\
  /.^         ^.\\
    
""", "main_color" : "\033[34m"
}

logo_long_blody = {
    "logo": """
 ▄▄▄       ██▀███   ▄████▄   ██░ ██ 
▒████▄    ▓██ ▒ ██▒▒██▀ ▀█  ▓██░ ██▒
▒██  ▀█▄  ▓██ ░▄█ ▒▒▓█    ▄ ▒██▀▀██░
░██▄▄▄▄██ ▒██▀▀█▄  ▒▓▓▄ ▄██▒░▓█ ░██ 
 ▓█   ▓██▒░██▓ ▒██▒▒ ▓███▀ ░░▓█▒░██▓
 ▒▒   ▓▒█░░ ▒▓ ░▒▓░░ ░▒ ▒  ░ ▒ ░░▒░▒
  ▒   ▒▒ ░  ░▒ ░ ▒░  ░  ▒    ▒ ░▒░ ░
  ░   ▒     ░░   ░ ░         ░  ░░ ░
      ░  ░   ░     ░ ░       ░  ░  ░
""", "main_color" : '\033[31m'
}

logo_long_devil = {
    "logo" : """
 (`-')  _    (`-')           (`-').->
 (OO ).-/ <-.(OO ) _         (OO )__ 
 / ,---.  ,------,)\\-,-----.,--. ,'-'
 | \\ /`.\\ |   /`. ' |  .--./|  | |  |
 '-'|_.' ||  |_.' |/_) (`-')|  `-'  |
(|  .-.  ||  .   .'||  |OO )|  .-.  |
 |  | |  ||  |\\  \\(_'  '--'\\|  | |  |
 `--' `--'`--' '--'  `-----'`--' `--'
""", "main_color" : '\033[31m'
}

columns, lines = os.get_terminal_size().columns, os.get_terminal_size().lines 
max_columns = 180
max_lines = 40

def get_layout():
    if columns <= 92 and lines <= 23:
        return layout_small

    elif columns <= 92:
        return layout_long

    else:
        return layout_big

    
def get_logo():
    if columns <= 92 and lines <= 23:
        return logo_small

    elif columns <= 92:
        return logo_long_devil

    else:
        return 'auto'


def get_logo_position():
    if columns <= 92 and lines <= 23:
        return 'left'

    elif columns <= 92:
        return 'top'

    else:
        return 'left'

def get_colorize_functions():
    if columns <= 92:
        return False
    return True

settings = {
    "layout": get_layout(),

    #{cursor_theme()} {gpu_driver()} {gtk_font()}

    # dictionary with custom functions, if you want to display something yours
    # pass functions here, and insert them into layout as in example above 
    # format : 
    #     'function_name' : function 

    "custom_fetches" : {},

    "colorize_functions" : get_colorize_functions(),
    # colorize function's output or no. if you want to insert specific color for the specific function output in line, then.
    # functions will be colored as text color if set to False. 
    # you have to set this param to False. This will disable colorizing for all the functions. you'll have to manually insert 
    # color for every function.to do that, you can use the following syntax: 
    # {cN}, where N is a number from 1 to 16. example:
    #
    # {c6} CPU: {cpu()}
    # 
    # example above will colorize all the line if colorize_functions set to false. 
    # if colorize functions set to True, then only "CPU: " will be colored.
    # 
    # colors are like in the example below. just past color number you want. for example:
    # {c6} colorize to magenta
    # {c2} colorize to red

    "text_color" : "logo", 
    # the color text will displayed with, text only, not result of functions
    # values :
    # 1:    # black
    # 2:    # red
    # 3:    # green
    # 4:    # yellow
    # 5:    # blue
    # 6:    # magenta
    # 7:    # cyan
    # 8:    # white
    # 9:   # bright black
    # 10:  # bright red
    # 11: # bright green
    # 12: # bright yellow
    # 13: # bright blue
    # 14: # bright magenta
    # 15: # bright cyan
    # 16: # bright white
    
    "functions_color": 8,
    # color of function's output, values are the same

    "logo" : get_logo(),
    # ascii logo to be displayed
    # values :
    #   'auto'   # automatically set logo 
    #   variable # dictionary with custom ascii art
    #       example and format:

    #       from colorama import Fore as f
    #
    #       example_logo = {
    #           "logo" : f"""{f.RED}
    #               /\\,-'''''-,/\\
    #               \\_)       (_/
    #               |  {f.WHITE}"    "{f.RED}   |
    #               |   {f.WHITE}----{f.RED}    |
    #               ;           ;
    #               "'-_____-'"
    #               """,
    #       "main_color" : f.RED  # main color of the logo. you can use ansii codes or python colorama module
    #                             # if logo is colorless leave it empy. if you have multicolored logo,
    #                             # manually insert colors per line, and set this as main color of logo
    #       }
     
    #   distro names:   # if you want exact distro ascci art, pass distro name with 'name_' prefix 
    #       name_arch (other are in progress)

    "logo_info_whitespace" : 3,
    # lenght of whitespace between logo and information

    "lstrip_info" : False,
    # remove whitespaces at the beginning of every layout line 

    "print_logo": True,
    # Print logo or no

    "logo_position": get_logo_position(),
    # position where logo located.
    #   values:  'left', 'top', 'right', 'bottom' 
}
