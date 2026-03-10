import { AlertTriangle } from "lucide-react";
import { clsx } from "clsx";
import type { PostureError } from "@/lib/types";

interface Props { errors: PostureError[] }

const SEVERITY_STYLES = {
  low:    "bg-info/10 text-info",
  medium: "bg-warning/10 text-warning",
  high:   "bg-danger/10 text-danger",
};

export default function PostureErrorList({ errors }: Props) {
  if (!errors.length) {
    return <p className="text-xs text-health">No significant posture issues detected.</p>;
  }

  return (
    <div className="flex flex-col gap-2">
      {errors.map((err) => (
        <div key={err.id} className="flex items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <AlertTriangle className="w-3.5 h-3.5 text-warning flex-shrink-0" />
            <span className="text-xs text-text-secondary capitalize">
              {err.error_type.replace(/_/g, " ")}
            </span>
            <span className="text-xs text-text-muted">— {err.occurrences}×</span>
          </div>
          <span className={clsx("text-xs font-medium px-1.5 py-0.5 rounded capitalize", SEVERITY_STYLES[err.severity])}>
            {err.severity}
          </span>
        </div>
      ))}
    </div>
  );
}
