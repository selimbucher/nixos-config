# Nautilus, closer to Finder where it offers no setting or CSS hook (its look
# is CSS in home/theme.nix):
# - Its smallest zoom steps put a 16px icon next to 11pt (14.7px) text in list
#   view and a 48px icon in the grid, which reads undersized next to Finder.
#   Only the "small" steps change (src/nautilus-enums.h).
# - No Recent and no Starred in the sidebar, and so no star column in the
#   list: without Starred there is nowhere to see starred files.
{
  lib,
  nautilus,
  gridSmall ? 56, # upstream 48
  listSmall ? 20, # upstream 16
}:

nautilus.overrideAttrs (old: {
  postPatch = (old.postPatch or "") + ''
    substituteInPlace src/nautilus-enums.h \
      --replace-fail "NAUTILUS_GRID_ICON_SIZE_SMALL       = 48" \
                     "NAUTILUS_GRID_ICON_SIZE_SMALL       = ${toString gridSmall}" \
      --replace-fail "NAUTILUS_LIST_ICON_SIZE_SMALL  = 16" \
                     "NAUTILUS_LIST_ICON_SIZE_SMALL  = ${toString listSmall}"

    substituteInPlace src/nautilus-sidebar.c \
      --replace-fail "if (should_show_recent (sidebar))" \
                     "if (should_show_recent (sidebar) && FALSE)" \
      --replace-fail 'start_icon = g_themed_icon_new_with_default_fallbacks ("starred-symbolic");' \
                     'start_icon = g_themed_icon_new_with_default_fallbacks ("starred-symbolic"); if (FALSE)'

    substituteInPlace src/nautilus-list-view.c \
      --replace-fail 'g_hash_table_insert (visible_columns_hash, g_strdup ("starred"), g_strdup ("starred"));' ";"
  '';
})
