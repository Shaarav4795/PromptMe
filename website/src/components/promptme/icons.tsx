const ICON_SPRITE_PATH = "/promptme/images/icons/ui-symbols.svg";

type SymbolIconProps = {
  symbolId: string;
  viewBox: string;
  width: number;
  height: number;
  className?: string;
};

function SymbolIcon({ symbolId, viewBox, width, height, className }: SymbolIconProps) {
  return (
    <svg className={className} width={width} height={height} viewBox={viewBox} xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <use href={`${ICON_SPRITE_PATH}#${symbolId}`} />
    </svg>
  );
}

export function ArrowIcon({ className = "c-arrow-icon" }: { className?: string }) {
  return <SymbolIcon symbolId="arrow-cta" viewBox="0 0 12 10" width={12} height={10} className={className} />;
}

export function CheckIcon({ className = "c-check-icon" }: { className?: string }) {
  return <SymbolIcon symbolId="check-mark" viewBox="0 0 12 12" width={12} height={12} className={className} />;
}

export function ListCheckIcon({ className = "c-list-check-icon" }: { className?: string }) {
  return (
    <svg className={className} width="20" height="20" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <use href={`${ICON_SPRITE_PATH}#list-check-circle`} />
      <use href={`${ICON_SPRITE_PATH}#list-check-tick`} />
    </svg>
  );
}
