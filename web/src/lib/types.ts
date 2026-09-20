export type Profile = {
  id: string;
  full_name: string;
  email: string;
  role: string;
  department_id: number | null;
  level: number | null;
  cgpa: number | null;
  target_career_id: number | null;
  data_consent: boolean;
};
export type Skill = {
  id: number;
  slug: string;
  name: string;
  category_id: number;
};
export type Named = {
  id: number;
  name: string;
  slug?: string;
  faculty?: string;
};
export type Requirement = {
  career_id: number;
  skill_id: number;
  target_rank: number;
  weight: number;
};
export type Opportunity = {
  id: string;
  slug: string;
  title: string;
  organization: string | null;
  description: string | null;
  category: string;
  url: string | null;
  source: string | null;
  location: string | null;
  is_remote: boolean;
  deadline: string | null;
  min_level: number | null;
  max_level: number | null;
  skills: { slug: string; name: string; weight: number }[];
  careers: string[];
  departments: number[];
};
export type Dataset = {
  profile: Profile;
  skills: Skill[];
  careers: Named[];
  departments: Named[];
  industries: Named[];
  categories: Named[];
  requirements: Requirement[];
  ranks: Record<string, number>;
  interests: number[];
  opportunities: Opportunity[];
  saved: string[];
};
export type FormState = { error?: string; success?: string };
