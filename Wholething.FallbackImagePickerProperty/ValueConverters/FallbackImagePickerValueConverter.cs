using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using Superpower;
#if NET5_0_OR_GREATER
using Umbraco.Cms.Core;
using Umbraco.Cms.Core.Models.PublishedContent;
using Umbraco.Cms.Core.PropertyEditors;
using Umbraco.Cms.Core.PublishedCache;
#else
using Umbraco.Core;
using Umbraco.Core.Models.PublishedContent;
using Umbraco.Core.PropertyEditors;
using Umbraco.Web.PublishedCache;
#endif

namespace Wholething.FallbackImagePickerProperty.ValueConverters
{
    public class FallbackImagePickerValueConverter : PropertyValueConverterBase
    {
        private readonly IPublishedSnapshotAccessor _publishedSnapshotAccessor;

        public FallbackImagePickerValueConverter(IPublishedSnapshotAccessor publishedSnapshotAccessor)
        {
            _publishedSnapshotAccessor = publishedSnapshotAccessor ??
                                         throw new ArgumentNullException(nameof(publishedSnapshotAccessor));
        }

        public override bool IsConverter(IPublishedPropertyType propertyType)
        {
            return propertyType.EditorAlias.Equals("FallbackImagePicker");
        }

        public override Type GetPropertyValueType(IPublishedPropertyType propertyType)
        {
            return typeof(IPublishedContent);
        }

        public override PropertyCacheLevel GetPropertyCacheLevel(IPublishedPropertyType propertyType)
            => PropertyCacheLevel.Snapshot;

        public override object ConvertSourceToIntermediate(IPublishedElement owner, IPublishedPropertyType propertyType,
            object source, bool preview)
        {
            if (source == null) return null;

            var nodeIds = source.ToString()
                .Split(new[] { "," }, StringSplitOptions.RemoveEmptyEntries)
                .Select(ParseUdi)
                .ToArray();

            return nodeIds;
        }

        public override object ConvertIntermediateToObject(IPublishedElement owner, IPublishedPropertyType propertyType,
            PropertyCacheLevel cacheLevel, object source, bool preview)
        {
            var ids = (Udi[])source;
            var mediaItems = new List<IPublishedContent>();

            if (source == null) return GetFallbackMediaItem(propertyType);

            if (ids.Any())
            {
                foreach (var id in ids)
                {
                    var item = GetPublishedSnapshot().Media.GetById(id);
                    if (item != null)
                        mediaItems.Add(item);
                }

                return FirstOrDefault(mediaItems);
            }

            return source;
        }

        private IPublishedSnapshot GetPublishedSnapshot()
        {
#if NET5_0_OR_GREATER
            _publishedSnapshotAccessor.TryGetPublishedSnapshot(out var publishedSnapshot);
            return publishedSnapshot;
#else
            return _publishedSnapshotAccessor.PublishedSnapshot;
#endif
        }

        private object FirstOrDefault(IList mediaItems)
        {
            return mediaItems.Count == 0 ? null : mediaItems[0];
        }

        private IPublishedContent GetFallbackMediaItem(IPublishedPropertyType propertyType)
        {
            var fallbackId = (string)((Dictionary<string, object>)propertyType.DataType.Configuration)["fallbackMediaId"];

            var udi = ParseUdi(fallbackId);
            if (udi == null) return null;

            return GetPublishedSnapshot()?.Media.GetById(udi);
        }

        private Udi ParseUdi(string value)
        {
#if NET5_0_OR_GREATER
            return Udi.Create(new Uri(value));
#else
            return Udi.Parse(value);
#endif
        }
    }
}