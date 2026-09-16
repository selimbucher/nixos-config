# Nautilus hardcodes its zoom-level icon sizes (src/nautilus-enums.h) and
# offers no setting or CSS hook for them. Its smallest steps put a 16px icon
# next to 11pt (14.7px) text in list view and a 48px icon in the grid, which
# reads undersized next to Finder. Only the "small" steps change here.
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
  '';
})
