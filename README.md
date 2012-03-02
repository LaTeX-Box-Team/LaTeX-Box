# LaTeX BoX
![LaTeX-BoX](https://raw.github.com/LaTeX-Box-Team/LaTeX-Box/master/doc/LaTeX-BoX.png)

## This plugin provides:
- Background compilation using latexmk;
- Completion for commands, environments, labels, and bibtex entries;
- A simple table of contents;
- Smart indentation (activated with "set smartindent");
- Highlight matching \begin/\end pairs;
- Motion between \begin/\end pairs with the % key;
- Motion through brackets/braces (with user-defined keys);
- Environment objects (e.g., select environement with "vie" or "vae");
- Inline math objects (e.g., select inline math with "vi$" or "va$").

See ":help latex-box" for more details.

This plugins aims at being lightweight and simple. For more fully-fledged plugins, see:

- LaTeX-Suite: vimscript#475
- AutomaticTexPlugin: vimscript#2945

## Installation
### With gmarik vundle
_https://github.com/gmarik/vundle_

Add `Bundle 'LaTeX-Box-Team/LaTeX-Box'` to your ~/.vimrc and run
`:BundleInstall` in a vim buffer. Add `!` to the command to update.

### Without a plugin manager

Copy the directories to your `.vim/` folder.

## Mirror information

This is mirrored on 

- http://www.vim.org/scripts/script.php?script_id=3109
- https://launchpad.net/~vim-latex-box
