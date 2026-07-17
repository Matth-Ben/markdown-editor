import Image from "next/image";
import Link from "next/link";
import { Card } from "@nexus/ui";
import type { Story } from "@nexus/core";

export function StoryCard({ story, coverUrl }: { story: Story; coverUrl: string | null }) {
  return (
    <Link href={`/story/${story.id}`} className="block rounded-xl">
      <Card className="flex flex-col transition-colors hover:border-accent-cyan/50">
        <div className="aspect-[3/2] bg-background">
          {coverUrl ? (
            <Image
              src={coverUrl}
              alt=""
              width={400}
              height={267}
              className="h-full w-full object-cover"
            />
          ) : null}
        </div>
        <div className="p-4">
          <h2 className="text-sm font-medium text-foreground">{story.title}</h2>
        </div>
      </Card>
    </Link>
  );
}
