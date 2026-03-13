"use client";
import { useCallback, useState } from "react";
import { Upload, X, FileVideo, Film } from "lucide-react";
import { clsx } from "clsx";

interface Props {
  onFile: (file: File) => void;
  disabled?: boolean;
}

export default function VideoUploader({ onFile, disabled }: Props) {
  const [dragging, setDragging]   = useState(false);
  const [selected, setSelected]   = useState<File | null>(null);

  const handleFile = (file: File) => {
    setSelected(file);
    onFile(file);
  };

  const onDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setDragging(false);
    const file = e.dataTransfer.files[0];
    if (file && file.type.startsWith("video/")) handleFile(file);
  }, []);

  const onInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) handleFile(file);
  };

  const clear = (e: React.MouseEvent) => {
    e.stopPropagation();
    setSelected(null);
  };

  return (
    <label
      onDragOver={(e) => { e.preventDefault(); setDragging(true); }}
      onDragLeave={() => setDragging(false)}
      onDrop={onDrop}
      className={clsx(
        "relative flex flex-col items-center justify-center min-h-[220px] rounded-xl border-2 border-dashed transition-all duration-200 cursor-pointer select-none",
        disabled ? "opacity-50 pointer-events-none" : "",
        dragging
          ? "border-primary bg-primary/[0.07] scale-[1.005]"
          : selected
          ? "border-health/50 bg-health/[0.04]"
          : "border-white/[0.09] bg-surface hover:border-primary/40 hover:bg-primary/[0.02]"
      )}
    >
      <input
        type="file"
        accept="video/*"
        className="hidden"
        onChange={onInputChange}
        disabled={disabled}
      />

      {selected ? (
        <div className="flex flex-col items-center gap-3 px-6 text-center">
          <div className="w-14 h-14 rounded-xl bg-health/10 border border-health/20 flex items-center justify-center">
            <FileVideo className="w-7 h-7 text-health" />
          </div>
          <div>
            <p className="text-sm font-semibold text-text-primary truncate max-w-xs">{selected.name}</p>
            <p className="text-xs text-text-muted mt-0.5">{(selected.size / 1024 / 1024).toFixed(1)} MB · ready to analyze</p>
          </div>
          <button
            type="button"
            onClick={clear}
            aria-label="Remove file"
            className="flex items-center gap-1 text-xs text-text-muted hover:text-danger transition-colors cursor-pointer px-3 py-1.5 rounded-lg hover:bg-danger/10"
          >
            <X className="w-3 h-3" />
            Remove
          </button>
        </div>
      ) : (
        <div className="flex flex-col items-center gap-4 px-6 text-center">
          <div className={clsx(
            "w-14 h-14 rounded-xl border flex items-center justify-center transition-all duration-200",
            dragging ? "bg-primary/20 border-primary/30" : "bg-primary/10 border-primary/15"
          )}>
            {dragging
              ? <Film   className="w-7 h-7 text-primary" />
              : <Upload className="w-7 h-7 text-primary" />}
          </div>
          <div>
            <p className="text-sm font-semibold text-text-primary">
              {dragging ? "Drop to upload" : "Drag your workout video here"}
            </p>
            <p className="text-xs text-text-muted mt-1">or click to browse files</p>
          </div>
          <div className="flex items-center gap-2 flex-wrap justify-center">
            {["MP4", "MOV", "AVI"].map((fmt) => (
              <span key={fmt} className="text-[10px] font-medium bg-surface-3 text-text-muted px-2 py-0.5 rounded">
                {fmt}
              </span>
            ))}
            <span className="text-xs text-text-muted">· Max 2 min</span>
          </div>
        </div>
      )}
    </label>
  );
}
