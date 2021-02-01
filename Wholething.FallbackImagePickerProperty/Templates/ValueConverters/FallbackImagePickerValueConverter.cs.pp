using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using Umbraco.Core;
using Umbraco.Core.Models.PublishedContent;
using Umbraco.Core.PropertyEditors;
using Umbraco.Web.PropertyEditors;
using Umbraco.Web.PublishedCache;

namespace $rootnamespace$.ValueConverters
{
    public class FallbackImagePickerValueConverter : PropertyValueConverterBase
    {
        // hard-coding "image" here but that's how it works at UI level too
        private const string ImageTypeAlias = "image";

        private readonly IPublishedModelFactory _publishedModelFactory;
        private readonly IPublishedSnapshotAccessor _publishedSnapshotAccessor;

        public FallbackImagePickerValueConverter(IPublishedSnapshotAccessor publishedSnapshotAccessor,
            IPublishedModelFactory publishedModelFactory)
        {
            _publishedSnapshotAccessor = publishedSnapshotAccessor ??
                                         throw new ArgumentNullException(nameof(publishedSnapshotAccessor));
            _publishedModelFactory = publishedModelFactory;
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
                .Select(Udi.Parse)
                .ToArray();
            return nodeIds;
        }

        public override object ConvertIntermediateToObject(IPublishedElement owner, IPublishedPropertyType propertyType,
            PropertyCacheLevel cacheLevel, object source, bool preview)
        {
            var udis = (Udi[])source;
            var mediaItems = new List<IPublishedContent>();

            if (source == null) return GetFallbackMediaItem(owner, propertyType);

            if (udis.Any())
            {
                foreach (var udi in udis)
                {
                    var guidUdi = udi as GuidUdi;
                    if (guidUdi == null) continue;
                    var item = _publishedSnapshotAccessor.PublishedSnapshot.Media.GetById(guidUdi.Guid);
                    if (item != null)
                        mediaItems.Add(item);
                }

                return FirstOrDefault(mediaItems);
            }

            return source;
        }

        private object FirstOrDefault(IList mediaItems)
        {
            return mediaItems.Count == 0 ? null : mediaItems[0];
        }

        private IPublishedContent GetFallbackMediaItem(IPublishedElement owner, IPublishedPropertyType propertyType)
        {
            var config = ((Dictionary<string, object>) propertyType.DataType.Configuration);

            config.TryGetValue("fallbackMediaId", out var fallbackMediaId);
            if (fallbackMediaId is string fallbackMediaIdStr && !string.IsNullOrEmpty(fallbackMediaIdStr))
            {
                return GetMediaItemFromUdiString(fallbackMediaIdStr);
            }

            config.TryGetValue("fallbackMediaProperty", out var fallbackMediaProperty);
            if (fallbackMediaProperty is string fallbackMediaPropertyStr && !string.IsNullOrEmpty(fallbackMediaPropertyStr))
            {
                var parts = fallbackMediaPropertyStr.Trim().Split(':');
                if (parts.Length == 1)
                {
                    var property = owner.GetProperty(parts[0]);
                    return GetMediaItemFromUdiString((string) property.GetSourceValue());
                }
                if (parts.Length == 2)
                {
                    var nodeId = int.Parse(parts[0]);
                    var node = _publishedSnapshotAccessor.PublishedSnapshot.Content.GetById(nodeId);
                    var property = node.GetProperty(parts[1]);
                    return GetMediaItemFromUdiString((string)property.GetSourceValue());
                }
            }

            return null;
        }

        private IPublishedContent GetMediaItemFromUdiString(string udiString)
        {
            GuidUdi.TryParse(udiString, out var guidUdi);
            if (guidUdi.Guid == Guid.Empty) return null;

            return _publishedSnapshotAccessor.PublishedSnapshot.Media.GetById(guidUdi.Guid);
        }
    }
}