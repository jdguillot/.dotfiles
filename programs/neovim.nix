{ pkgs, ... }:
{

  programs.neovim = {
    enable = true;
    withPython3 = true;
    plugins = with pkgs.vimPlugins; [
      coc-nvim
      coc-python
      context-filetype
      # nerdree
      neo-tree-nvim
      fugitive
      # onedark-vim
      vim-tmux-navigator
      comment-nvim
      nvim-treesitter.withAllGrammars
    ];
    extraConfig = ''
      set relativenumber
      set number
      set tabstop=2
      set expandtab
      set shiftwidth=2
      set softtabstop=2
      set wrap
      set linebreak
      set list
      set lcs+=space:·
      syntax on
      set ignorecase
      set smartcase
      set hlsearch
      set autoindent
      set clipboard=unnamedplus
      nnoremap <C-s> <ESC>:w<CR>
      nnoremap <C-e> :Neotree filesystem reveal<CR>
      nnoremap <M-Up> :m -2<CR>
      nnoremap <M-Down> :m +1<CR>

      nnoremap <C-/> gcc
      vnoremap <C-/> gc
      inoremap <ESC>gccA

      " Coc Nvim

      inoremap <silent><expr> <TAB>
           \ coc#pum#visible() ? coc#pum#next(1) :
           \ CheckBackspace() ? "\<Tab>" :
           \ coc#refresh()
      inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

      " Use <c-space> to trigger completion
      if has('nvim')
        inoremap <silent><expr> <c-space> coc#refresh()
      else
        inoremap <silent><expr> <c-@> coc#refresh()
      endif

      function! CheckBackspace() abort
        let col = col('.') - 1
        return !col || getline('.')[col - 1]  =~# '\s'
      endfunction

      " Use <c-space> to trigger completion
      if has('nvim')
        inoremap <silent><expr> <c-space> coc#refresh()
      else
        inoremap <silent><expr> <c-@> coc#refresh()
      endif
    '';
  };


}
