"use client";
import { useCallback, useState } from "react";
import { Upload, X, FileVideo } from "lucide-react";
import { clsx } from "clsx";

interface Props {
  onFile: (file: File) => void;
  disabled?: boolean;
}

export default function VideoUploader({ onFile, disabled }: Props) {
  const [dragging, setDragging] = useState(false);
  const [selected, setSelected] = useState<File | null>(null);

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
        "relative flex flex-col items-center justify-center min-h-[240px] rounded-2xl border-2 border-dashed transition-all duration-200 cursor-pointer",
        disabled ? "opacity-50 pointer-events-none" : "",
        dragging
          ? "border-primary/60 bg-primary/[0.06]"
          : selected
          ? "border-health/40 bg-health/[0.03]"
          : "border-white/10 bg-surface hover:border-primary/40 hover:bg-primary/[0.02]"
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
          <div className="w-12 h-12 rounded-xl bg-health/10 flex items-center justify-center">
            <FileVideo className="w-6 h-6 text-health" />
          </div>
          <div>
            <p className="text-sm font-medium text-text-primary">{selected.name}</p>
            <p className="text-xs text-text-muted mt-0.5">{(selected.size / 1024 / 1024).toFixed(1)} MB</p>
          </div>
          <button
            type="button"
            onClick={clear}
            className="text-xs text-text-muted hover:text-danger transition-colors flex items-center gap-1 cursor-pointer"
          >
            <X className="w-3 h-3" /> Remove
          </button>
        </div>
      ) : (
        <div className="flex flex-col items-center gap-3 px-6 text-center">
          <div className="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center">
            <Upload className="w-6 h-6 text-primary" />
          </div>
          <div>
            <p className="text-sm font-medium text-text-primary">Drag your workout video here</p>
            <p className="text-xs text-text-muted mt-0.5">or click to browse</p>
          </div>
          <p className="text-xs text-text-muted">Supported: MP4, MOV, AVI · Max 2 min</p>
        </div>
      )}
    </label>
  );
}
