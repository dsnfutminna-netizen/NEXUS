import Link from "next/link";
import { ArrowUpRight, Bookmark, MapPin } from "lucide-react";
import type { Dataset, Opportunity } from "@/lib/types";
import { score, sample, earlyCareer, safeUrl } from "@/lib/intelligence";
import { ActionForm } from "./form";
import { toggleSaved } from "@/app/app/actions";
export function OpportunityCard({ d, o }: { d: Dataset; o: Opportunity }) {
  const result = score(d, o),
    isSample = sample(o),
    saved = d.saved.includes(o.id);
  return (
    <article className="opportunity-card">
      <div className="opportunity-top">
        <span className="org-mark">
          {(o.organization || o.title).slice(0, 2).toUpperCase()}
        </span>
        <div>
          <span className="eyebrow">
            {o.organization || "Independent listing"}
          </span>
          <h3>
            <Link href={"/app/opportunities/" + o.id}>{o.title}</Link>
          </h3>
        </div>
        <span className="tag">{isSample ? "Sample" : o.category}</span>
      </div>
      <p className="location">
        <MapPin size={14} />
        {o.location || (o.is_remote ? "Remote" : "Location not stated")}
      </p>
      <div className="tags">
        <span>
          {earlyCareer(o) ? "Early career" : "Check experience requirements"}
        </span>
        <span>{o.source || "Curated"}</span>
      </div>
      {d.profile.data_consent && (
        <div className="coverage">
          <div>
            <b>{result.coverage}%</b>
            <span> tagged skills coverage</span>
          </div>
          <div className="bar">
            <i style={{ width: result.coverage + "%" }} />
          </div>
        </div>
      )}
      <div className="card-actions">
        <Link className="card-link" href={"/app/opportunities/" + o.id}>
          View opportunity <ArrowUpRight size={16} />
        </Link>
        <ActionForm
          action={toggleSaved}
          label={saved ? "Saved ✓" : "Save"}
          className="save-form"
        >
          <input type="hidden" name="id" value={o.id} />
          <input type="hidden" name="remove" value={String(saved)} />
        </ActionForm>
      </div>
    </article>
  );
}
